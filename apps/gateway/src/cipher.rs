use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use rand::RngCore;
use std::fs;
use std::path::Path;

#[derive(Clone)]
pub struct Cipher {
    key: [u8; 32],
}

impl Cipher {
    pub fn new<P: AsRef<Path>>(directory: P) -> Result<Self, String> {
        let dir = directory.as_ref();
        let _ = fs::create_dir_all(dir);
        let key_path = dir.join("gateway.key");

        let key = if key_path.exists() {
            let bytes = fs::read(&key_path).map_err(|e| format!("Failed to read gateway.key: {}", e))?;
            if bytes.len() != 32 {
                return Err(format!("Invalid gateway.key length: expected 32, got {}", bytes.len()));
            }
            let mut k = [0u8; 32];
            k.copy_from_slice(&bytes);
            k
        } else {
            let mut k = [0u8; 32];
            rand::thread_rng().fill_bytes(&mut k);

            #[cfg(unix)]
            {
                use std::os::unix::fs::OpenOptionsExt;
                let mut options = fs::OpenOptions::new();
                options.write(true).create_new(true).mode(0o600);
                use std::io::Write;
                let mut file = options.open(&key_path).map_err(|e| format!("Failed to create gateway.key: {}", e))?;
                file.write_all(&k).map_err(|e| format!("Failed to write gateway.key: {}", e))?;
            }

            #[cfg(not(unix))]
            {
                fs::write(&key_path, &k).map_err(|e| format!("Failed to write gateway.key: {}", e))?;
            }

            k
        };

        Ok(Self { key })
    }

    pub fn encrypt(&self, plaintext: &str) -> Result<String, String> {
        let cipher = Aes256Gcm::new_from_slice(&self.key).map_err(|e| format!("Cipher init error: {}", e))?;

        let mut nonce_bytes = [0u8; 12];
        rand::thread_rng().fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = cipher.encrypt(nonce, plaintext.as_bytes()).map_err(|e| format!("Encryption error: {}", e))?;

        let mut combined = Vec::with_capacity(12 + ciphertext.len());
        combined.extend_from_slice(&nonce_bytes);
        combined.extend_from_slice(&ciphertext);

        Ok(BASE64.encode(combined))
    }

    pub fn decrypt(&self, blob: &str) -> Result<String, String> {
        let raw = BASE64.decode(blob).map_err(|e| format!("Base64 decode error: {}", e))?;

        if raw.len() < 12 {
            return Err("Encrypted blob is too short".into());
        }

        let (nonce_bytes, ciphertext) = raw.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);

        let cipher = Aes256Gcm::new_from_slice(&self.key).map_err(|e| format!("Cipher init error: {}", e))?;

        let decrypted = cipher.decrypt(nonce, ciphertext).map_err(|e| format!("Decryption error: {}", e))?;

        String::from_utf8(decrypted).map_err(|e| format!("UTF-8 decode error: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SECRET: &str = r#"{"access_token": "secret_abc123", "expires_at": 1794404630}"#;

    fn cipher() -> (Cipher, tempfile::TempDir) {
        let tmp = tempfile::tempdir().unwrap();
        (Cipher::new(tmp.path()).unwrap(), tmp)
    }

    #[test]
    fn encrypted_text_differs_from_the_plaintext() {
        let (c, _d) = cipher();
        assert_ne!(c.encrypt(SECRET).unwrap(), SECRET);
    }

    #[test]
    fn decrypt_reverses_encrypt() {
        let (c, _d) = cipher();
        let enc = c.encrypt(SECRET).unwrap();
        assert_eq!(c.decrypt(&enc).unwrap(), SECRET);
    }

    #[test]
    fn decrypting_garbage_fails() {
        let (c, _d) = cipher();
        assert!(c.decrypt("not-a-ciphertext").is_err());
    }

    #[test]
    fn the_key_is_reused_across_instances_in_the_same_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let enc = Cipher::new(tmp.path()).unwrap().encrypt(SECRET).unwrap();
        assert_eq!(Cipher::new(tmp.path()).unwrap().decrypt(&enc).unwrap(), SECRET);
    }
}
