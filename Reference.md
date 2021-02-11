## Directory Structure
- `/lib` - Flutter directory - takes dart code and turns it into iOS and Android native applications
- `/nebula` - Build for mobile
- `/android & /ios` - Shims for stitching together frontend (user facing) config items to persisted state and client configurations

## Persisted State
State is stored using two different platform specific mechanisms. iOS applications stores its site specific data in a VPN configuration. Android state is persisted via Keychain(?)/encrypted filesystem. Flutter models help us persist data in a structured format but requires some native code (Kotlin/Swift) to parse and store the data (i.e. `android/` & `ios/`). 

### Site
Found in `lib/models/Site.dart` this file represents the state that will be persisted to the nebula client running on the device. Most settings described here are available on storage and retrieval. One notable exception here is the storage of the private key the client uses to authenticate with other Nebula hosts. To properly handle and protect the sensitive key material this key cannot be viewed from the client.

### Certificates
There are a few different classes defined in `lib/models/Certificate.dart` that all have distinct purposes. Additionally there is `CertificateResult` defined in `lib/screens/siteConfig/CertificateScreen` which parses the returned cert and aides in the secure storage of the private key. The general class hierarchy looks something like this: `CertificateResult > CertificateInfo > Certificate > CertificateDetails`. `CertificateResult` is a vehicle for storing the private key invoked by hitting the "Generate" button. 

### App Config
Is used to persist user settings that are mostly display oriented i.e dark mode or log wrapping. These user configurations are encapsulated by the `Settings` class defined in `lib/services/settings.dart`. These settings are persisted separately from Site configuration and stored in a `config.json` file on the device. These settings are **not** ingested by the nebula binary that runs natively on the device.