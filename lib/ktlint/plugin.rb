require 'json'

module Danger
  class DangerKtlint < Plugin
    
    class UnexpectedLimitTypeError < StandardError
    end

    # TODO: Lint all files if `filtering: false`
    attr_accessor :filtering

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
    # def lint(files: nil, inline_mode: false)
    def lint(files: nil, inline_mode: false)
      unless ktlint_exists?
        fail("Couldn't find ktlint command. Install first.")
        return
      end

      files ||= git.added_files + git.modified_files
      targets = target_files(files)
      return if targets.empty?

      results = JSON.parse(`ktlint #{targets.join(' ')} --reporter=json --relative`)
      return if results.empty?

      if inline_mode
        send_inline_comments(results)
      else
        send_markdown_comment(results)
      end
    end

    # Comment to a PR by ktlint result json
    #
    # // Sample ktlint result
    # [
    #   {
    #     "file": "app/src/main/java/com/mataku/Model.kt",
    # 		"errors": [
    # 			{
    # 				"line": 46,
    # 				"column": 1,
    # 				"message": "Unexpected blank line(s) before \"}\"",
    # 				"rule": "no-blank-line-before-rbrace"
    # 			}
    # 		]
    # 	}
    # ]
    def send_markdown_comment(results)
      catch(:loop_break) do
        count = 0
        results.each do |result|
          result['errors'].each do |error|
            file = "#{result['file']}#L#{error['line']}"
            message = "#{github.html_link(file)}: #{error['message']}"
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
    end

    def send_inline_comments(results)
      catch(:loop_break) do
        count = 0
        print "\nresults : #{results}\n"
        results.each do |result|
          result['errors'].each do |error|
            file = result['file']
            message = error['message']
            line = error['line']
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
    end

    def target_files(changed_files)
      changed_files.select do |file|
        file.end_with?('.kt')
      end
    end

    private

    def ktlint_exists?
      system 'which ktlint > /dev/null 2>&1' 
    end
  end
end
