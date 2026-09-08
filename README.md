# dotfiles

NixOS + home-manager configuration, managed with [chezmoi](https://chezmoi.io).

## New machine

On a fresh NixOS install, as user `julian`:

```bash
curl -fsSL https://raw.githubusercontent.com/JulianElda/dotfiles/master/install.sh | bash -s -- <hostname>
```

Then follow the stage-2 steps the script prints.
