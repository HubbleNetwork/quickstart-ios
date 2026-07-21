# Contributing

Thanks for your interest in the Hubble Gateway SDK iOS Quickstart.

This repo is primarily a reference implementation maintained by the Hubble team. We're happy to accept contributions for:

- Bug fixes
- Documentation improvements
- Build/CI improvements
- Compatibility fixes for new iOS versions or Xcode releases

For larger feature changes or architectural shifts, please open an issue first to discuss before writing code.

## Reporting bugs

Open a [GitHub issue](https://github.com/HubbleNetwork/quickstart-ios/issues) with:

- What you expected to happen
- What actually happened
- Steps to reproduce
- Your device, iOS version, and SDK version (e.g. `gateway-sdk 0.6.0`)
- Relevant logs (with sensitive info redacted)

For security vulnerabilities, see [SECURITY.md](SECURITY.md).

## Pull requests

1. Create a feature branch.
2. Make your changes. Keep them focused: one PR per logical change.
3. Verify the build passes locally:
   ```bash
   xcodebuild build -scheme HubbleGatewaySample -destination "platform=iOS Simulator,name=iPhone 16,OS=latest"
   ```
4. Open a PR with a clear description of what changed and why.

## SDK changes

The Hubble Gateway SDK itself is a separate, commercial product maintained in [`gateway-sdk`](https://github.com/HubbleNetwork/gateway-sdk-ios). Changes to SDK behavior must be made there, not here. This repo only demonstrates SDK usage.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE), the same license that covers this project.
