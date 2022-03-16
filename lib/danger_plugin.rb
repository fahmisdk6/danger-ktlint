# frozen_string_literal: true

require "json"

module Danger
  class DangerKtlint < Plugin
    # Throw error for unexpected limit type
    class UnexpectedLimitTypeError < StandardError
      def initialize(message = "Limit have to be integer")
        super(message)
      end
    end

    SUPPORTED_SERVICES = %w(GitHub GitLab BitBucket).freeze
    AVAILABLE_SERVICES = SUPPORTED_SERVICES.map { |service| service.downcase.to_sym }

    # Throw error for unsupported scm service
    class UnsupportedServiceError < StandardError
      def initialize(message = "Unsupported service! Currently supported services are #{SUPPORTED_SERVICES.join(',')} server.")
        super(message)
      end
    end

    # Lint all files on `filtering: false`
    attr_accessor :filtering

    attr_accessor :skip_lint, :report_file, :report_files_pattern, :limit

    # Run ktlint task using command line interface
    # Will fail if `ktlint` is not installed
    # Skip lint task if files changed are empty
    # @return [void]
    def lint(files: [], inline_mode: false, &filter_block)
      raise UnsupportedServiceError unless supported_service?

      raise UnexpectedLimitTypeError if !limit.nil? && !limit.kind_of?(Numeric)

      files = git.added_files + git.modified_files if files.nil? || files.empty?
      targets = target_files(files)
      results = ktlint_results(targets)
      return if results.nil? || results.empty?

      # Restructured ktlint result
      results = results.map do |ktlint_result|
        ktlint_result.map do |result|
          result["errors"].map do |error|
            {
              "file" => result["file"],
              "line" => error["line"],
              "column" => error["column"],
              "message" => error["message"],
              "rule" => error["rule"]
            }
          end.flatten
        end.flatten
      end.flatten

      # Allow modify result with filter block statement
      results = results.filter { |result| filter_block.call(result) } if filter_block

      if inline_mode
        send_inline_comments(results, targets)
      else
        send_markdown_comment(results, targets)
      end
    end

    private

    # Comment to a PR by ktlint result json
    #
    # Sample ktlint result
    # [
    #   {
    #     "file" => "/src/main/java/com/mataku/Model.kt",
    #     "line" => 46,
    #     "column" => 1,
    #     "message" => "Unexpected blank line(s) before \"}\"",
    #   "rule" => "no-blank-line-before-rbrace"
    #   }
    # ]
    def send_markdown_comment(results, targets)
      catch(:loop_break) do
        count = 0
        results.each do |result|
          file_path = relative_file_path(result["file"])
          next unless targets.include?(file_path)

          message = "#{file_html_link(file_path, result['line'])}: #{result['message']}"
          fail(message)
          next if limit.nil?

          count += 1
          throw(:loop_break) if count >= limit
        end
      end
    end

    def send_inline_comments(results, targets)
      catch(:loop_break) do
        count = 0
        results.each do |result|
          file_path = relative_file_path(result["file"])
          next unless targets.include?(file_path)

          message = result["message"]
          line = result["line"]
          # Why not file_path?
          fail(message, file: result["file"], line: line)
          next if limit.nil?

          count += 1
          throw(:loop_break) if count >= limit
        end
      end
    end

    def target_files(changed_files)
      changed_files.filter { |file| file.end_with?(".kt") }
    end

    # Make it a relative path so it can compare it to git.added_files
    def relative_file_path(file_path)
      file_path.delete_prefix(Dir.pwd)
    end

    def file_html_link(file_path, line_number)
      file = if danger.scm_provider == :github
               "#{file_path}#L#{line_number}"
             else
               file_path
             end
      scm_provider_klass.html_link(file)
    end

    # `eval` may be dangerous, but it does not accept any input because it accepts only defined as danger.scm_provider
    # rubocop:disable Security/Eval
    def scm_provider_klass
      @scm_provider_klass ||= eval(danger.scm_provider.to_s)
    end
    # rubocop:enable Security/Eval

    def ktlint_installed?
      system "which ktlint > /dev/null 2>&1"
    end

    def ktlint_results(targets)
      if skip_lint
        # TODO: Allow XML (will require nokogiri)
        ktlint_result_files.map do |file|
          JSON.parse(File.read(file, encoding: "UTF-8"))
        end
      else
        unless ktlint_installed?
          fail("Couldn't find ktlint command. Install first.")
          return
        end

        filtering = true if filtering.nil?
        ktlint_targets = filtering ? targets.join(" ") : "**/*.kt"
        return if ktlint_targets.empty?

        # On latest kotlint there is debug log, instead of just the json report
        # 10:47:20.076 [main] DEBUG com.pinterest.ktlint.Main - Discovered
        # Maybe can transform to
        # ktlint_result = `ktlint #{ktlint_targets} --reporter=json --relative`
        # report = ktlint_result.split("\n").map { |line| next line unless line.match?(/^\d+:.*/) }.compact.join("\n")
        # JSON.parse(report)
        report_file_path = "ktlint_report.json"
        system "ktlint #{ktlint_targets} --reporter=json,output=#{report_file_path} --relative"
        [JSON.parse(File.read(report_file_path, encoding: "utf-8"))]
      end
    end

    def supported_service?
      AVAILABLE_SERVICES.include?(danger.scm_provider.to_sym)
    end

    def ktlint_result_files
      if !report_file.to_s.strip.empty? && File.exist?(report_file)
        [report_file]
      elsif !report_files_pattern.to_s.strip.empty?
        Dir[report_files_pattern]
      else
        fail("Couldn't find ktlint result json file.\nYou must specify it with `ktlint.report_file=...` or `ktlint.report_files_pattern=...` in your Dangerfile.")
        []
      end
    end
  end
end
