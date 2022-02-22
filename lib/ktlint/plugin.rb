# frozen_string_literal: true

require 'json'

module Danger
  class DangerKtlint < Plugin
    class UnexpectedLimitTypeError < StandardError; end

    class UnsupportedServiceError < StandardError
      def initialize(message = 'Unsupported service! Currently supported services are GitHub, GitLab and BitBucket server.')
        super(message)
      end
    end

    AVAILABLE_SERVICES = [:github, :gitlab, :bitbucket_server]

    # TODO: Lint all files if `filtering: false`
    attr_accessor :filtering

    attr_accessor :skip_lint, :report_file

    def limit
      @limit ||= nil
    end

    def limit=(limit)
      if limit != nil && limit.integer?
        @limit = limit
      else
        raise UnexpectedLimitTypeError
      end
    end

    # Run ktlint task using command line interface
    # Will fail if `ktlint` is not installed
    # Skip lint task if files changed are empty
    # @return [void]
    def lint(files: [], inline_mode: false, &select_block)
      unless supported_service?
        raise UnsupportedServiceError.new
      end

      files ||= git.added_files + git.modified_files
      targets = target_files(files)
      return if targets.empty?

      results = ktlint_results(targets)
      return if results.nil? || results.empty?

      # Restructured ktlint result
      results = results.reduce([]) do |acc, result|
        acc + result['errors'].map do |error|
          {
            'file' => result['file'],
            'line' => error['line'],
            'column' => error['column'],
            'message' => error['message'],
            'rule' => error['rule']
          }
        end
      end
      results = results.filter { |result| select_block.call(result) } if select_block

      if inline_mode
        send_inline_comments(results, targets)
      else
        send_markdown_comment(results, targets)
      end
    end

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
          file_path = relative_file_path(result['file'])
          next unless targets.include?(file_path)

          message = "#{file_html_link(file_path, result['line'])}: #{result['message']}"
          fail(message)
          unless limit.nil?
            count += 1
            if count >= limit
              throw(:loop_break)
            end
          end
        end
      end
    end

    def send_inline_comments(results, targets)
      catch(:loop_break) do
        count = 0
        results.each do |result|
          file_path = relative_file_path(result['file'])
          next unless targets.include?(file_path)

          message = result['message']
          line = result['line']
          # Why not file_path?
          fail(message, file: result['file'], line: line)
          unless limit.nil?
            count += 1
            if count >= limit
              throw(:loop_break)
            end
          end
        end
      end
    end

    def target_files(changed_files)
      changed_files.filter { |file| file.end_with?('.kt') }
    end

    # Make it a relative path so it can compare it to git.added_files
    def relative_file_path(file_path)
      file_path.gsub(/#{pwd}\//, '')
    end

    private

    def file_html_link(file_path, line_number)
      file = if danger.scm_provider == :github
               "#{file_path}#L#{line_number}"
             else
               file_path
             end
      scm_provider_klass.html_link(file)
    end

    # `eval` may be dangerous, but it does not accept any input because it accepts only defined as danger.scm_provider
    def scm_provider_klass
      @scm_provider_klass ||= eval(danger.scm_provider.to_s)
    end

    def pwd
      @pwd ||= `pwd`.chomp
    end

    def ktlint_installed?
      system 'which ktlint > /dev/null 2>&1' 
    end

    def ktlint_results(targets)
      if skip_lint
        # TODO: Allow XML
        if report_file.to_s.empty?
          fail("If skip_lint is specified, You must specify ktlint report json file with `ktlint.report_file=...` in your Dangerfile.")
          return
        end

        unless File.exists?(report_file)
          fail("Couldn't find ktlint result json file.\nYou must specify it with `ktlint.report_file=...` in your Dangerfile.")
          return
        end

        JSON.load(File.read(report_file, encoding: 'UTF-8'))
      else
        unless ktlint_installed?
          fail("Couldn't find ktlint command. Install first.")
          return
        end

        return if targets.empty?

        JSON.parse(`ktlint #{targets.join(' ')} --reporter=json --relative`)
      end
    end

    def supported_service?
      AVAILABLE_SERVICES.include?(danger.scm_provider.to_sym)
    end
  end
end
