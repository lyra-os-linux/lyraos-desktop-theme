# Lyra OS

Identidade visual para GNOME 48+, criada para o Lyra OS e para openSUSE. A
configuração recomendada usa Adwaita no Shell e nos aplicativos, com ícones e
wallpapers Lyra OS.

## Componentes

- Adwaita nativo para GNOME Shell, GTK 4/libadwaita e GTK 3
- Tema vetorial `Lyra-OS-Icons`, com fallback completo para Adwaita
- Wallpapers dark e light em PNG e JPEG XL, 3840×2160
- Tema do GRUB 2 com fundo Full HD e menu de boot Lyra OS
- Tema de boot do Plymouth com o mesmo fundo e logo do GRUB
- Tela de login do GDM com ícones, wallpaper e cores do GNOME Shell Lyra OS
- Configs do Fastfetch e Neofetch com logo ascii da Lyra e cores da marca
- Pacotes RPM para openSUSE

## Instalação rápida

Revise o [install.sh](install.sh) antes de executá-lo. Requer openSUSE
(`zypper`). Para usar Adwaita escuro com ícones e wallpaper Lyra OS:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install.sh | bash
```

Variante light:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install.sh | bash -s -- --light
```

### Instalação pelos pacotes RPM

Para adicionar o repositório OBS, instalar os RPMs e ativar automaticamente
os ícones, wallpapers, GRUB, Plymouth, o GDM e as configurações do Fastfetch e
Neofetch:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install-rpm.sh | bash
```

Para usar a variante clara:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install-rpm.sh | bash -s -- --light
```

O instalador instala as dependências via `zypper`, compila os arquivos,
instala tema, ícones, wallpapers, GRUB, Plymouth e a tela de login do GDM,
ativa Adwaita com os ícones Lyra OS no GNOME, o menu de boot do GRUB,
o splash de boot do Plymouth e o tema Lyra OS no GDM (ícones,
wallpaper e cores do Shell), e copia os configs do Fastfetch e Neofetch com o
logo ascii da Lyra para o perfil atual. Configurações existentes recebem um
backup antes da substituição. A senha administrativa é solicitada diretamente
pelo terminal.

As mensagens de `install.sh` e `install-rpm.sh` estão disponíveis em
pt-BR, en-US e es, seguindo o idioma do ambiente (`LANG`/`LC_ALL`/
`LC_MESSAGES`) com fallback para en-US. Para forçar um idioma, defina
`LYRA_LANG`:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install.sh | \
  LYRA_LANG=es bash
```

### Opções

```text
--dark          usa Adwaita escuro com ícones e wallpaper Lyra (padrão)
--light         usa Adwaita claro com ícones e wallpaper Lyra
--no-activate   instala sem modificar preferências do GNOME, do GRUB, do
                Plymouth, do GDM ou os configs do Fastfetch e Neofetch
--no-grub       não instala nem ativa o tema do GRUB
--no-plymouth   não instala nem ativa o tema do Plymouth
--no-gdm        não ativa o tema Lyra OS na tela de login do GDM
--full-theme    também estiliza as janelas (headerbars GTK 3/4) e a barra
                superior/overview do GNOME Shell com o Lyra OS, em vez de
                manter o chrome padrão do Adwaita. Pode quebrar a aparência
                dos Quick Settings do Shell em algumas versões do GNOME.
--uninstall     remove os arquivos e restaura as preferências
--help          mostra a ajuda
```

Exemplo para instalar sem ativação automática:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install.sh | bash -s -- --no-activate
```

## Requisitos

- GNOME 48 ou superior
- openSUSE, com `zypper`
- `curl`, `tar`, `gzip`, `xz`, `sassc`, Node.js, `rsvg-convert` e ImageMagick
  7 com suporte a JXL
- `glib2-tools`, `gtk3-tools`, `adwaita-icon-theme` e `fastfetch`
- `grub2`, `plymouth-scripts`, `plymouth-plugin-two-step`,
  `plymouth-theme-spinner`, `cantarell-fonts` e `dracut` para os temas de boot
- `dconf` e `gnome-shell-extension-user-theme` para o tema do GDM

O instalador resolve esses pacotes automaticamente via `zypper`.

## Build a partir do repositório

```bash
git clone https://github.com/lyra-os-linux/lyraos-desktop-theme.git
cd Lyra-Theme
./scripts/build.sh
./scripts/build-icons.sh
./scripts/package.sh
```

Os resultados são gravados em `dist/`. O último comando também gera
`Lyra-OS.tar.xz`. O build executa automaticamente a validação WCAG das
paletas dark e light.

Para compilar e instalar diretamente a partir deste checkout (sem baixar um
tarball do GitHub), use:

```bash
./scripts/install-local.sh
```

Aceita as mesmas opções do `install.sh` (`--dark`, `--light`,
`--no-activate`, `--no-grub`, `--no-plymouth`, `--no-gdm`, `--uninstall`) e
também instala as dependências de build via `zypper` (`sassc`, Node.js,
`rsvg-convert`, ImageMagick) e todas as dependências de execução dos
componentes habilitados.

## Instalação manual

```bash
sudo install -d /usr/share/themes /usr/share/icons \
  /usr/share/backgrounds/lyra /usr/share/gnome-background-properties \
  /usr/share/grub/themes /usr/share/plymouth/themes \
  /usr/share/lyra-os-theme/fastfetch
sudo cp -a dist/Lyra-OS dist/Lyra-OS-Light /usr/share/themes/
sudo cp -a dist/Lyra-OS-Icons /usr/share/icons/
sudo install -m 0644 dist/backgrounds/*.{png,jxl} /usr/share/backgrounds/lyra/
sudo install -m 0644 dist/gnome-background-properties/lyra-os.xml \
  /usr/share/gnome-background-properties/
sudo cp -a dist/grub/Lyra-OS /usr/share/grub/themes/
sudo cp -a dist/plymouth/Lyra-OS /usr/share/plymouth/themes/
sudo install -d /usr/lib/dracut/modules.d/51lyra-plymouth
sudo install -m 0755 dist/dracut/51lyra-plymouth/module-setup.sh \
  /usr/lib/dracut/modules.d/51lyra-plymouth/module-setup.sh
sudo cp -a dist/fastfetch/. /usr/share/lyra-os-theme/fastfetch/
mkdir -p ~/.config/neofetch
cp dist/neofetch/config.conf ~/.config/neofetch/config.conf
mkdir -p ~/.config/fastfetch
cp dist/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
```

## Ativação manual

### Adwaita com ícones Lyra OS

```bash
gsettings reset org.gnome.shell.extensions.user-theme name
gsettings reset org.gnome.desktop.interface gtk-theme
gsettings set org.gnome.desktop.interface icon-theme 'Lyra-OS-Icons'
gsettings set org.gnome.desktop.interface accent-color 'blue'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

O GNOME Shell e os aplicativos permanecem no Adwaita padrão; somente os ícones
são fornecidos pelo Lyra OS. Isso mantém compatibilidade integral com
os controles rápidos das versões atuais do GNOME.

### Estilo Lyra OS nas janelas e no Shell (`--full-theme`)

Por padrão o instalador não estiliza as janelas nem o Shell — ele só troca os
ícones, mantendo o chrome do Adwaita, pelos motivos acima. Os arquivos do tema
completo (headerbars GTK 3/4 e barra superior/overview do GNOME Shell) já são
compilados em `dist/Lyra-OS` e `dist/Lyra-OS-Light`; a flag `--full-theme`
ativa esse tema nas janelas e no Shell, em vez de só nos ícones:

```bash
./scripts/install-local.sh --full-theme
```

Isso requer `gnome-shell-extension-user-theme` (instalada automaticamente
junto com essa flag) e pode alterar a aparência dos Quick Settings do GNOME
Shell em algumas versões — por isso não é o padrão. Para ativar manualmente
sem o instalador:

```bash
gsettings set org.gnome.desktop.interface gtk-theme 'Lyra-OS'
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
gsettings set org.gnome.shell.extensions.user-theme name 'Lyra-OS'
mkdir -p ~/.config/gtk-4.0
ln -sf /usr/share/themes/Lyra-OS/gtk-4.0/gtk.css ~/.config/gtk-4.0/gtk.css
```

Use `Lyra-OS-Light` nos três comandos para a variante clara. Rodar
`--uninstall` (ou os comandos `gsettings reset`/remover o symlink acima)
restaura o Adwaita padrão.

### Variante clara

Use:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
```

### GRUB

O instalador ativa o tema em `/etc/default/grub` e regenera o `grub.cfg` com
`grub2-mkconfig`. Para ativá-lo manualmente, acrescente:

```bash
GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"
```

Depois execute `sudo grub2-mkconfig -o /boot/grub2/grub.cfg`. O instalador só
remove essa configuração na desinstalação se ela ainda apontar para o tema
Lyra.

### Plymouth

O instalador ativa o tema com `plymouth-set-default-theme -R Lyra-OS`
(o `-R` já regenera o initramfs) quando esse comando está disponível, e
guarda o tema anterior para restaurá-lo na desinstalação. Para ativar
manualmente:

```bash
sudo plymouth-set-default-theme -R Lyra-OS
```

O splash usa o fundo BGRT fornecido pelo firmware, mantém o logotipo do
fabricante, posiciona a animação abaixo dele e mostra a marca Lyra OS no
rodapé. Quando BGRT não está disponível, usa `#0b1018` como fundo. O módulo
Dracut incluído garante que `label-pango.so` seja copiado para o initramfs no
openSUSE, evitando quadrados no lugar das mensagens e do prompt de senha.

### GDM

O instalador ativa o tema na tela de login criando um perfil `gdm` no
`dconf` (`/etc/dconf/profile/gdm`, só se ainda não existir) e um arquivo de
banco de dados em `/etc/dconf/db/gdm.d/00-lyra-os` com o ícone, o
wallpaper e a extensão `user-theme` apontando para o tema Lyra OS
(ou `Lyra-OS-Light`, na variante clara), seguido de `dconf update`.
Requer o pacote `gnome-shell-extension-user-theme` para que as cores do Shell
sejam aplicadas; sem ele, o GDM ainda recebe os ícones e o wallpaper Lyra,
mas mantém as cores padrão do Shell. Para ativar manualmente:

```bash
sudo tee /etc/dconf/db/gdm.d/00-lyra-os >/dev/null <<'EOF'
[org/gnome/desktop/interface]
icon-theme='Lyra-OS-Icons'
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/lyra/lyra-voyage.png'
picture-uri-dark='file:///usr/share/backgrounds/lyra/lyra-voyage.png'
picture-options='zoom'

[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com']

[org/gnome/shell/extensions/user-theme]
name='Lyra-OS'
EOF
sudo dconf update
```

Na desinstalação, o instalador remove `/etc/dconf/db/gdm.d/00-lyra-os`
e também `/etc/dconf/profile/gdm` — mas só se o perfil não existia antes da
instalação.

### neofetch

O config em `src/neofetch/config.conf` (copiado para
`~/.config/neofetch/config.conf` pelo instalador) troca o logo ascii pelo
mark da Lyra e exibe o nome e a versão de `/etc/os-release`, colorido com a
paleta da marca, mantendo o resto das opções padrão do neofetch. Para
aplicá-lo manualmente:

```bash
mkdir -p ~/.config/neofetch
cp dist/neofetch/config.conf ~/.config/neofetch/config.conf
```

### Fastfetch

O config em `src/fastfetch/config.jsonc` usa o logo ascii Lyra localizado em
`/usr/share/lyra-os-theme/fastfetch/logo.txt` e exibe o nome e a versão de
`/etc/os-release`. O instalador cria um backup do config atual
antes de ativá-lo. Para aplicar manualmente:

```bash
mkdir -p ~/.config/fastfetch
cp dist/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
```

## Pacotes

### openSUSE / RPM

As especificações estão em:

- `packaging/lyra-os-theme.spec`
- `packaging/lyra-os-icons.spec`

Exemplo de build no ambiente padrão do RPM:

```bash
rpmbuild -bb packaging/lyra-os-theme.spec
rpmbuild -bb packaging/lyra-os-icons.spec
```

O pacote ativa os temas do GRUB, do Plymouth e do GDM, e instala os ícones e
wallpapers como padrões do GNOME. Perfis existentes que já tenham preferências
próprias não são sobrescritos pelo RPM. Os configs do Fastfetch e Neofetch são
instalados em `/etc/skel` para novos usuários e como referências em
`/usr/share/lyra-os-theme/`. Use o `install-rpm.sh` acima para aplicar
todas essas configurações também ao usuário atual.

## Estrutura

```text
src/shell/       tokens SCSS e tema GNOME Shell
src/gtk4/        overrides GTK 4/libadwaita
src/gtk3/        port GTK 3 e atribuição LGPL
src/icons/       tema de ícones SVG
src/wallpaper/   fonte vetorial e metadados GNOME
src/grub/        tema, fundo e seleção do menu GRUB
src/plymouth/    configuração BGRT e integração Dracut do tema Plymouth
src/neofetch/    config do neofetch com logo ascii da Lyra
src/fastfetch/   config e logo ascii para o Fastfetch
scripts/         build, validação e empacotamento
packaging/       especificações RPM
```

## Desinstalação

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/install.sh | bash -s -- --uninstall
```

## Licenças

O projeto é distribuído sob GPL-3.0-or-later. O componente GTK 3 mantém
LGPL-2.1-or-later e a atribuição ao adw-gtk3 em
`src/gtk3/ATTRIBUTION.md`. O tema não substitui fontes e não altera
configurações do usuário durante a instalação por pacote; o GDM é ajustado
apenas via `dconf` (perfil `gdm`), sem tocar nas preferências do usuário
logado.
