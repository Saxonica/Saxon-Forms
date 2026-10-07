/**
 * Entry point for the noble-hashes crypto bundle.
 * Exposes the subset of @noble/hashes needed by Saxon-Forms
 * digest() and hmac() functions.
 */
export { sha1, md5 } from '@noble/hashes/legacy.js';
export { sha256, sha384, sha512 } from '@noble/hashes/sha2.js';
export { hmac } from '@noble/hashes/hmac.js';
export { bytesToHex } from '@noble/hashes/utils.js';
