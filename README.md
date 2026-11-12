# MyTeam Video

MyTeam Video is a Flutter client and self-hosted video-management service. The repository contains the cross-platform application, service source, build configuration, and project documentation.

## Repository layout

- `lib/`, `test/` — Flutter application and tests
- `android/`, `windows/`, `macos/`, `ios/` — platform integrations and packaging
- `server/` — service implementation
- `docs/` — architecture, development, and operational documentation

## Client quick start

Install the Flutter SDK version specified by the repository toolchain configuration, then run from the repository root:

```sh
flutter pub get
flutter run
```

For local service development, configure `MYTEAM_API_BASE_URL` at build/run time with `--dart-define`; release builds default to the public production API. Container registry publishing is manual, opt-in, and restricted to a protected ref. Never put private endpoints or credentials in source.

## Documentation

- [Documentation map](docs/README.md)
- [Client documentation](docs/APP/INDEX.md)
- [Production release contract and gates](docs/APP/PRODUCTION-RELEASE.md)
- [Contributor boundaries](docs/ROSTER.md)

## License

Original MyTeam-authored source is licensed under [GNU GPL-3.0-only](LICENSE). Third-party components and assets retain their own licenses and notices. The native third-party binary provenance/license audit is deferred until after launch as known debt; it is not complete and this repository makes no compliance-clearance claim. This source publication is not a production binary release, feed publication, or production GO.
