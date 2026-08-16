# Security and Credential Policy

This is a public MMKPC Studios showcase repository. The original production repository remains private.

- Never commit API keys, access tokens, passwords, private keys, certificates, or machine-specific secret files.
- Use environment variables or a local secret manager for runtime credentials.
- If a credential is exposed, revoke or rotate it first. Removing the file does not invalidate a credential in Git history.
- Do not report suspected credentials in a public issue. Route a report through MMKProspects.com.

Run the repository validator before any studio release:

```powershell
pwsh ./scripts/validate_studio_manifest.ps1
```
