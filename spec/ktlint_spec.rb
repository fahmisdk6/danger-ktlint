# frozen_string_literal: true

require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerKtlint do
    let(:dangerfile) { testing_dangerfile }
    let(:plugin) { dangerfile.ktlint }

    it "should be a plugin" do
      expect(Danger::DangerKtlint.new(nil)).to be_a Danger::Plugin
    end

    describe "#lint" do
      before do
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["app/src/main/java/com/mataku/Model.kt"])
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return(["app/src/main/com/mataku/DataModel.java"])
      end

      context "`ktlint` is not installed" do
        before do
          allow_any_instance_of(Kernel).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(false)
        end

        it "Fails with message about not found `ktlint`" do
          plugin.lint
          expect(dangerfile.status_report[:errors]).to eq(["Couldn't find ktlint command. Install first."])
        end
      end

      context "Ktlint issues were found" do
        before do
          allow_any_instance_of(Kernel).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
          allow_any_instance_of(Kernel).to receive(:system).with("ktlint app/src/main/java/com/mataku/Model.kt --reporter=json,output=ktlint_report.json --relative").and_return(true)
          allow(File).to receive(:read).with("ktlint_report.json", encoding: "utf-8").and_return(dummy_ktlint_result)
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L46").and_return("<a href='https://github.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L47").and_return("<a href='https://github.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
        end

        it "Sends markdown comment" do
          plugin.lint
          expect(dangerfile.status_report[:errors].size).to eq(2)
        end

        context "lint with with passed block" do
          it "filter out results from Model.kt line 47" do
            plugin.lint(inline_mode: true) { |result| result["line"] != 47 }
            expect(dangerfile.status_report[:errors].size).to eq(1)
          end
        end
      end

      context "Ktlint issues were found with inline_mode: true" do
        before do
          allow_any_instance_of(Kernel).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
          allow_any_instance_of(Kernel).to receive(:system).with("ktlint app/src/main/java/com/mataku/Model.kt --reporter=json,output=ktlint_report.json --relative").and_return(true)
          allow(File).to receive(:read).with("ktlint_report.json", encoding: "utf-8").and_return(dummy_ktlint_result)
        end

        it "Sends inline comment" do
          plugin.lint(inline_mode: true)
          expect(dangerfile.status_report[:errors].size).to eq(2)
        end
      end

      context "GitLab" do
        let(:dangerfile) { testing_dangerfile_for_gitlab }

        before do
          allow_any_instance_of(Kernel).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
          allow_any_instance_of(Kernel).to receive(:system).with("ktlint app/src/main/java/com/mataku/Model.kt --reporter=json,output=ktlint_report.json --relative").and_return(true)
          allow(File).to receive(:read).with("ktlint_report.json", encoding: "utf-8").and_return(dummy_ktlint_result)
          allow_any_instance_of(Danger::DangerfileGitLabPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L46").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          allow_any_instance_of(Danger::DangerfileGitLabPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L47").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
        end

        it do
          plugin.lint
          expect(dangerfile.status_report[:errors].size).to eq(2)
        end
      end

      context "Bitbucket" do
        let(:dangerfile) { testing_dangerfile_for_bitbucket }

        before do
          allow_any_instance_of(Kernel).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
          allow_any_instance_of(Kernel).to receive(:system).with("ktlint app/src/main/java/com/mataku/Model.kt --reporter=json,output=ktlint_report.json --relative").and_return(true)
          allow(File).to receive(:read).with("ktlint_report.json", encoding: "utf-8").and_return(dummy_ktlint_result)
          allow_any_instance_of(Danger::DangerfileBitbucketServerPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          allow_any_instance_of(Danger::DangerfileBitbucketServerPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
        end

        it do
          plugin.lint
          expect(dangerfile.status_report[:errors].size).to eq(2)
        end
      end
    end

    describe "#limit" do
      context "expected limit value is set" do
        it "raises UnexpectedLimitTypeError" do
          # Allow nil as it is the default value
          plugin.limit = "1"
          expect { plugin.lint }.to raise_error(Danger::DangerKtlint::UnexpectedLimitTypeError)
        end
      end

      context "integer value is set to limit" do
        it "raises no errors" do
          expect { plugin.limit = 1 }.not_to raise_error
        end
      end
    end

    describe "#send_markdown_comment" do
      let(:limit) { 1 }

      before do
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["app/src/main/java/com/mataku/Model.kt"])
        allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])
        allow_any_instance_of(Kernel).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
        allow_any_instance_of(Kernel).to receive(:system).with("ktlint app/src/main/java/com/mataku/Model.kt --reporter=json,output=ktlint_report.json --relative").and_return(true)
        allow(File).to receive(:read).with("ktlint_report.json", encoding: "utf-8").and_return(dummy_ktlint_result)
        plugin.limit = limit
      end

      context "limit is set" do
        it "equals number of ktlint results to limit" do
          plugin.lint(inline_mode: true)
          expect(dangerfile.status_report[:errors].size).to eq(limit)
        end
      end
    end

    describe "#skip_lint" do
      context "report_file path is specified" do
        before do
          allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["app/src/main/java/com/mataku/Model.kt"])
          allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L46").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L47").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")

          allow(plugin).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
          plugin.report_file = "./spec/fixtures/ktlint_result.json"
        end

        it do
          expect(plugin).not_to have_received(:system).with("which ktlint > /dev/null 2>&1")
          plugin.lint(inline_mode: false)
        end
      end

      context "report_files_pattern is specified" do
        before do
          allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:added_files).and_return(["app/src/main/java/com/mataku/Model.kt", "app/src/main/java/com/mataku/Model2.kt"])
          allow_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L46").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L47").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model2.kt#L46").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model2.kt'>Model2.kt</a>")
          allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model2.kt#L47").and_return("<a href='https://gitlab.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model2.kt'>Model2.kt</a>")
          allow(plugin).to receive(:system).with("which ktlint > /dev/null 2>&1").and_return(true)
          plugin.report_files_pattern = "**/ktlint_result*.json"
        end

        it do
          expect(plugin).not_to have_received(:system).with("which ktlint > /dev/null 2>&1")
          plugin.lint(inline_mode: false)
          expect(dangerfile.status_report[:errors].size).to eq(4)
        end
      end
    end

    describe "lint with select box" do
      context "report_file, report_file_pattern is not set and ktlint is not installed" do
        it "should fail when lint" do
          plugin.lint(files: ["app/src/main/java/com/mataku/Model.kt"])
          expect(dangerfile.status_report[:errors]).to eq(["Couldn't find ktlint command. Install first."])
        end
      end

      context "report_file not exist" do
        before do
          plugin.report_file = "non_existent_report.txt"
        end

        it "should fail when lint" do
          plugin.lint(files: ["app/src/main/java/com/mataku/Model.kt"])
          expect(dangerfile.status_report[:errors]).to eq(["Couldn't find ktlint result json file.\nYou must specify it with `ktlint.report_file=...` or `ktlint.report_files_pattern=...` in your Dangerfile."])
        end
      end

      context "when report_file is set" do
        context "when report_file has issues" do
          before do
            plugin.report_file = File.expand_path("fixtures/ktlint_result.json", __dir__)
            allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L46").and_return("<a href='https://github.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
            allow_any_instance_of(Danger::DangerfileGitHubPlugin).to receive(:html_link).with("app/src/main/java/com/mataku/Model.kt#L47").and_return("<a href='https://github.com/mataku/android/blob/561827e46167077b5e53515b4b7349b8ae04610b/Model.kt'>Model.kt</a>")
          end

          it "should fail when lint" do
            plugin.lint(files: ["app/src/main/java/com/mataku/Model.kt"])
            expect(dangerfile.status_report[:errors].size).to eq(2)
          end
        end
      end
    end
  end
end
