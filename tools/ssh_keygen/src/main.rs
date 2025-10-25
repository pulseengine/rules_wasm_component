/*!
# Hermetic SSH Key Generation Tool

A minimal, hermetic replacement for OpenSSH's ssh-keygen tool that generates
SSH key pairs compatible with OpenSSH format. This eliminates the need for
external OpenSSH dependencies in Bazel builds.

## Features

- Generates Ed25519, RSA, and ECDSA key pairs
- OpenSSH-compatible format output
- No external dependencies beyond Rust crates
- Command-line interface compatible with ssh-keygen basics

## Usage

```bash
# Generate Ed25519 key pair (default)
ssh-keygen -f mykey -N "" -C "comment"

# Generate RSA key pair
ssh-keygen -t rsa -b 2048 -f mykey -N "" -C "comment"

# Generate ECDSA key pair
ssh-keygen -t ecdsa -f mykey -N "" -C "comment"
```
*/

use anyhow::{Context, Result};
use clap::{Parser, ValueEnum};
use ssh_key::{Algorithm, LineEnding, PrivateKey};
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "ssh-keygen")]
#[command(about = "Generate SSH key pairs in OpenSSH format")]
#[command(version)]
struct Cli {
    /// Key type to generate
    #[arg(short = 't', long = "type", value_enum, default_value = "ed25519")]
    key_type: KeyType,

    /// Specify the filename of the key file
    #[arg(short = 'f', long = "filename", required = true)]
    filename: PathBuf,

    /// Provide a new passphrase (empty string for no passphrase)
    #[arg(short = 'N', long = "new-passphrase", default_value = "")]
    passphrase: String,

    /// Provide a comment for the key
    #[arg(short = 'C', long = "comment", default_value = "")]
    comment: String,

    /// Key size in bits (for RSA keys)
    #[arg(short = 'b', long = "bits")]
    bits: Option<u32>,

    /// Verbose output
    #[arg(short = 'v', long = "verbose")]
    verbose: bool,
}

#[derive(Clone, Debug, ValueEnum)]
enum KeyType {
    #[value(name = "ed25519")]
    Ed25519,
    #[value(name = "rsa")]
    Rsa,
    #[value(name = "ecdsa")]
    Ecdsa,
}

impl KeyType {
    fn to_algorithm(&self, bits: Option<u32>) -> Result<Algorithm> {
        match self {
            KeyType::Ed25519 => Ok(Algorithm::Ed25519),
            KeyType::Rsa => {
                let key_size = bits.unwrap_or(2048);
                if key_size < 1024 || key_size > 8192 {
                    anyhow::bail!("RSA key size must be between 1024 and 8192 bits");
                }
                Ok(Algorithm::Rsa { hash: None })
            }
            KeyType::Ecdsa => {
                // Default to P-256 for ECDSA
                Ok(Algorithm::Ecdsa {
                    curve: ssh_key::EcdsaCurve::NistP256,
                })
            }
        }
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    if cli.verbose {
        println!("Generating SSH key pair...");
        println!("Key type: {:?}", cli.key_type);
        println!("Filename: {}", cli.filename.display());
        if !cli.comment.is_empty() {
            println!("Comment: {}", cli.comment);
        }
    }

    // Determine algorithm
    let algorithm = cli
        .key_type
        .to_algorithm(cli.bits)
        .context("Failed to determine key algorithm")?;

    // Generate the private key using OS CSPRNG
    // OsRng is the recommended cryptographic RNG for key generation
    let mut private_key = PrivateKey::random(&mut rand::rngs::OsRng, algorithm)
        .context("Failed to generate private key")?;

    // Set comment if provided
    if !cli.comment.is_empty() {
        private_key.set_comment(&cli.comment);
    }

    // Get the public key
    let public_key = private_key.public_key();

    // Write private key file
    let private_key_data = if cli.passphrase.is_empty() {
        // No encryption
        private_key
            .to_openssh(LineEnding::LF)
            .context("Failed to encode private key")?
    } else {
        anyhow::bail!("Encrypted private keys are not yet supported");
    };

    fs::write(&cli.filename, private_key_data)
        .with_context(|| format!("Failed to write private key to {}", cli.filename.display()))?;

    // Set private key file permissions (Unix only)
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&cli.filename)?.permissions();
        perms.set_mode(0o600); // rw-------
        fs::set_permissions(&cli.filename, perms)
            .context("Failed to set private key file permissions")?;
    }

    // Write public key file
    let public_key_file = cli.filename.with_extension("pub");
    let public_key_data = public_key
        .to_openssh()
        .context("Failed to encode public key")?;

    fs::write(&public_key_file, format!("{}\n", public_key_data)).with_context(|| {
        format!(
            "Failed to write public key to {}",
            public_key_file.display()
        )
    })?;

    if cli.verbose {
        println!("Private key saved to: {}", cli.filename.display());
        println!("Public key saved to: {}", public_key_file.display());
        println!(
            "Key fingerprint: {}",
            public_key.fingerprint(ssh_key::HashAlg::Sha256)
        );
    } else {
        // Mimic ssh-keygen output format
        println!(
            "Generating public/private {} key pair.",
            match cli.key_type {
                KeyType::Ed25519 => "ed25519",
                KeyType::Rsa => "rsa",
                KeyType::Ecdsa => "ecdsa",
            }
        );
        println!(
            "Your identification has been saved in {}",
            cli.filename.display()
        );
        println!(
            "Your public key has been saved in {}",
            public_key_file.display()
        );
        println!("The key fingerprint is:");
        println!("{}", public_key.fingerprint(ssh_key::HashAlg::Sha256));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_ed25519_key_generation() -> Result<()> {
        let temp_dir = TempDir::new()?;
        let key_path = temp_dir.path().join("test_ed25519");

        let cli = Cli {
            key_type: KeyType::Ed25519,
            filename: key_path.clone(),
            passphrase: String::new(),
            comment: "test key".to_string(),
            bits: None,
            verbose: false,
        };

        // Generate key using our algorithm
        let algorithm = cli.key_type.to_algorithm(cli.bits)?;
        let private_key = PrivateKey::random(&mut rand::rngs::OsRng, algorithm)?;

        // Verify we can encode both private and public keys
        let _private_data = private_key.to_openssh(LineEnding::LF)?;
        let _public_data = private_key.public_key().to_openssh()?;

        Ok(())
    }

    #[test]
    fn test_rsa_key_generation() -> Result<()> {
        let algorithm = KeyType::Rsa.to_algorithm(Some(2048))?;
        let private_key = PrivateKey::random(&mut rand::rngs::OsRng, algorithm)?;

        // Verify we can encode both keys
        let _private_data = private_key.to_openssh(LineEnding::LF)?;
        let _public_data = private_key.public_key().to_openssh()?;

        Ok(())
    }

    #[test]
    fn test_key_type_validation() {
        // Test valid RSA key sizes
        assert!(KeyType::Rsa.to_algorithm(Some(2048)).is_ok());
        assert!(KeyType::Rsa.to_algorithm(Some(4096)).is_ok());

        // Test invalid RSA key sizes
        assert!(KeyType::Rsa.to_algorithm(Some(512)).is_err());
        assert!(KeyType::Rsa.to_algorithm(Some(16384)).is_err());

        // Test Ed25519 (bits parameter should be ignored)
        assert!(KeyType::Ed25519.to_algorithm(None).is_ok());
        assert!(KeyType::Ed25519.to_algorithm(Some(2048)).is_ok());
    }
}
