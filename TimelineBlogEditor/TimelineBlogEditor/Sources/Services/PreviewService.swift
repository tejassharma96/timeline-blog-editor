import Foundation
import AppKit

/// Service for running Jekyll preview server
@MainActor
final class PreviewService: ObservableObject {

    enum PreviewState: Equatable {
        case idle
        case installingDependencies
        case starting
        case running(url: URL)
        case error(String)
    }

    @Published var state: PreviewState = .idle

    private var process: Process?
    private var blogDirectoryURL: URL?
    private var hasAttemptedBundleInstall = false
    private var monitorTask: Task<Void, Never>?

    /// The default Jekyll server URL
    private let defaultPort = 4000

    /// Starts the Jekyll preview server
    func startPreview(blogDirectory: URL) {
        // Stop any existing preview
        stopPreview()

        self.blogDirectoryURL = blogDirectory
        self.hasAttemptedBundleInstall = false
        state = .starting

        // Run in background task
        Task.detached { [weak self] in
            await self?.attemptJekyllServe(in: blogDirectory)
        }
    }

    /// Stops the Jekyll preview server
    func stopPreview() {
        monitorTask?.cancel()
        monitorTask = nil

        if let process = process, process.isRunning {
            process.terminate()

            // Also kill any child processes (jekyll spawns ruby)
            Task.detached {
                let killTask = Process()
                killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                killTask.arguments = ["-f", "jekyll serve"]
                try? killTask.run()
            }
        }
        process = nil
        state = .idle
        hasAttemptedBundleInstall = false
    }

    /// Opens the preview URL in the default browser
    func openInBrowser() {
        guard case .running(let url) = state else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    private func attemptJekyllServe(in directory: URL) async {
        do {
            try await runJekyllServe(in: directory)
        } catch {
            await MainActor.run {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    private func runJekyllServe(in directory: URL) async throws {
        let process = Process()

        await MainActor.run {
            self.process = process
        }

        // Use interactive login shell to run bundle exec jekyll serve
        // -i: interactive (sources .zshrc where mise/rbenv/asdf are typically initialized)
        // -l: login shell (sources .zprofile, .zlogin)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-l", "-c", "cd '\(directory.path)' && bundle exec jekyll serve 2>&1"]
        process.currentDirectoryURL = directory

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        // Monitor output in background
        await monitorOutput(pipe: pipe, directory: directory)
    }

    private func runBundleInstall(in directory: URL) async -> Bool {
        await MainActor.run {
            self.state = .installingDependencies
        }

        print("Running bundle install in \(directory.path)...")

        let process = Process()
        // Use interactive login shell to pick up mise/rbenv/asdf from user's shell config
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-l", "-c", "cd '\(directory.path)' && bundle install 2>&1"]
        process.currentDirectoryURL = directory

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()

            // Wait for completion in background
            return await withCheckedContinuation { continuation in
                process.terminationHandler = { proc in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        print("Bundle install output: \(output)")
                    }

                    let exitCode = proc.terminationStatus
                    print("Bundle install exit code: \(exitCode)")
                    continuation.resume(returning: exitCode == 0)
                }
            }
        } catch {
            print("Bundle install failed: \(error)")
            return false
        }
    }

    private func monitorOutput(pipe: Pipe, directory: URL) async {
        var serverStarted = false
        var accumulatedOutput = ""
        var needsBundleInstall = false

        // Read config to get baseurl
        let baseurl = await Task.detached {
            let configURL = directory.appendingPathComponent("_config.yml")
            if let configContent = try? String(contentsOf: configURL, encoding: .utf8) {
                for line in configContent.components(separatedBy: .newlines) {
                    if line.hasPrefix("baseurl:") {
                        let value = line.replacingOccurrences(of: "baseurl:", with: "").trimmingCharacters(in: .whitespaces)
                        return value.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                    }
                }
            }
            return ""
        }.value

        let handle = pipe.fileHandleForReading

        // Read output asynchronously
        while true {
            // Check if process is still running
            let isRunning = await MainActor.run { self.process?.isRunning ?? false }

            // Read available data without blocking
            let data: Data? = await Task.detached {
                // Use a small read to avoid blocking
                return try? handle.availableData
            }.value

            guard let data = data else {
                if !isRunning { break }
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }

            if data.isEmpty {
                if !isRunning { break }
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }

            if let output = String(data: data, encoding: .utf8) {
                accumulatedOutput += output
                print("Jekyll output: \(output)")

                // Check for server address in output
                if !serverStarted && output.contains("Server address:") {
                    var foundURL: URL?

                    // Extract URL
                    if let range = output.range(of: "Server address: ") {
                        let urlStart = output[range.upperBound...]
                        if let endRange = urlStart.range(of: "\n") ?? urlStart.range(of: " ") {
                            let urlString = String(urlStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                            foundURL = URL(string: urlString)
                        }
                    }

                    // Fallback to default URL
                    if foundURL == nil {
                        let urlString = "http://127.0.0.1:\(defaultPort)\(baseurl)/"
                        foundURL = URL(string: urlString)
                    }

                    if let url = foundURL {
                        serverStarted = true
                        await MainActor.run {
                            self.state = .running(url: url)
                        }

                        // Auto-open in browser after a short delay
                        try? await Task.sleep(for: .seconds(1))
                        await MainActor.run {
                            self.openInBrowser()
                        }
                    }
                }

                // Check for bundle install needed errors
                if !serverStarted && !needsBundleInstall {
                    let bundleErrorIndicators = [
                        "Could not find",
                        "Bundler::GemNotFound",
                        "bundle install",
                        "Run `bundle install`",
                        "Could not locate Gemfile"
                    ]

                    for indicator in bundleErrorIndicators {
                        if accumulatedOutput.contains(indicator) {
                            needsBundleInstall = true
                            break
                        }
                    }
                }
            }
        }

        // Process ended - check if we need to run bundle install
        if !serverStarted {
            let shouldAttemptInstall = await MainActor.run { !self.hasAttemptedBundleInstall }

            if needsBundleInstall && shouldAttemptInstall {
                await MainActor.run {
                    self.hasAttemptedBundleInstall = true
                }

                print("Bundle install needed, running automatically...")

                let installSuccess = await runBundleInstall(in: directory)

                if installSuccess {
                    await MainActor.run {
                        self.state = .starting
                    }
                    // Retry jekyll serve
                    await attemptJekyllServe(in: directory)
                } else {
                    await MainActor.run {
                        self.state = .error("Bundle install failed. Try running 'bundle install' manually in the blog directory.")
                    }
                }
            } else {
                await MainActor.run {
                    if case .starting = self.state {
                        if needsBundleInstall {
                            self.state = .error("Bundle install failed. Try running 'bundle install' manually.")
                        } else {
                            self.state = .error("Jekyll server stopped unexpectedly. Check the console for details.")
                        }
                    }
                }
            }
        }
    }

    deinit {
        // Clean up on dealloc - terminate process synchronously
        if let process = process, process.isRunning {
            process.terminate()
        }
    }
}
