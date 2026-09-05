# Lyra OS Theme

O pacote `lyra-os-theme` mantém o visual de boot (GRUB e Plymouth), o logo do
GDM e a integração dos ícones e wallpapers do Lyra. **GTK3, GTK4/libadwaita e
GNOME Shell usam o padrão do GNOME**, sem folhas de estilo do Lyra.

No GNOME, a cor de destaque escolhida nas Configurações seleciona a variante
correspondente dos ícones Lyra. O serviço da sessão acompanha mudanças de cor
mesmo com o Vega fechado. As nove variantes vêm do pacote `lyra-os-icons`;
wallpapers Dawn e Voyage vêm de `lyra-os-wallpapers`.

A atualização e o próximo login migram seleções antigas de GTK/Shell Lyra para
Adwaita e Shell padrão. O auxiliar remove apenas CSS identificado como Lyra ou
imports do antigo tema; restaura o backup anterior quando disponível e preserva
CSS independente do usuário. Temas de ícones de terceiros são preservados.
A integração só atua em sessões GNOME: KDE e XFCE não são modificados.

## Build e testes

```bash
./scripts/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
rpmbuild -bb packaging/lyra-os-theme.spec
```

O build requer `rsvg-convert` e Cantarell. A integração de sessão usa Python 3
e PyGObject. O nome `lyra-os-apply-full-theme` permanece por compatibilidade
com atualizações anteriores; a entrada de autostart o executa com `--watch`.

O wallpaper padrão do pacote é `/usr/share/backgrounds/lyra/2702-voyage.png`.
A imagem GNOME define `2702-dawn.png` como seu padrão inicial.
