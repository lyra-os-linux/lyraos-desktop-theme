# Lyra OS Theme

Tema oficial do Lyra OS para GNOME/GTK, GDM, GRUB e Plymouth.

Os componentes visuais são distribuídos em projetos e RPMs independentes:

- `lyra-os-theme`: este repositório;
- `lyra-os-icons`: `lyraos-desktop-icons`;
- `lyra-os-wallpapers`: `lyraos-desktop-wallpapers`.

O pacote de tema requer os pacotes de ícones e wallpapers para que os padrões
do GNOME e do GDM sempre encontrem os recursos referenciados.

## Build

```bash
./scripts/build.sh
rpmbuild -bb packaging/lyra-os-theme.spec
```

O wallpaper padrão da versão 27.02 é
`/usr/share/backgrounds/lyra/2702-voyage.png`.
