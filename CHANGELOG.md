## 1.6.0
- Addressed an issue with Cbor decoding.
- Enhanced secret storage definition to encrypt and decrypt bytes instead of strings. This resolves a compatibility issue with Ethereum keystore.


## 1.5.0
- Added a new class for signing and verifying Ethereum and tron transactions.

## 1.4.1
- Corrected Ripple address encoding for ED25519
- Added support for Ripple ED25519 coin

## 1.4.0
- Downgrade DART SDK version from 2.17.1 to 2.15.0

## 1.3.0
- Downgrade DART SDK version from 3.1.1 to 2.17.1 to address compatibility issues and ensure smoother integration.
- Added a new class for signing and verifying Ripple transactions.

## 1.2.1
- Resolved an issue with byte order in the method IntUtils.toBytes for more consistent behavior.

## 1.2.0
- Fixed several bugs to enhance the stability and reliability of the code.
- Added utility functions to handle XRP X-address format for improved compatibility.
- Resolved an issue with byte order in the method IntUtils.toBytes for more consistent behavior.

## 1.1.0
- Implementing custom exception classes for more effective error handling.

## 1.0.6
- Resolved issue with CBOR decoding of lists
- Removed "tags" property from CBOR
- Introduced a new class for CBOR tags
- Added convenient utilities for signing and verifying Bitcoin transactions

## Changelog for Major Release 1.0.3

We're excited to present our biggest update yet, introducing a wide range of new features and enhancements to our toolkit. In this release, we've expanded our offering to include comprehensive support for various data encoding formats, blockchain addresses, advanced cryptographic algorithms, and cross-platform capabilities. Here's what you can expect:

**New Features and Enhancements:**

- Added support for encoding and decoding across numerous formats, including Base32, Hex, and more.
- Extensive support for a wide range of blockchain addresses, covering popular networks like Bitcoin, Ethereum, and beyond.
- A rich set of cryptographic algorithms, enhancing data security and integrity.
- Cross-platform compatibility, extending to iOS, Android, the web, and Linux.
- Mnemonic management, now complemented by BIP39 compliance.

This major release marks a significant step forward, making our toolkit an all-in-one solution for crypto enthusiasts, developers, and businesses. Embrace the future of encoding, cryptography, and blockchain interaction with confidence. Upgrade today and explore the endless possibilities our package offers.

[Full Release Notes](https://github.com/mrtnetwork/blockchain_utils) for more details on this groundbreaking release.
