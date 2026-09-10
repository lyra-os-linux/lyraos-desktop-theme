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

## Recuperação e limites da reversão

O antigo `scripts/rollback-full-theme.sh` foi retirado: dependia de
`scripts/install-local.sh`, que não existe mais. Não há um comando de
desinstalação local ou rollback completo neste repositório. Reverter uma
preferência visual não equivale a desinstalar os pacotes do tema.

Para mudar a aparência da sessão, escolha as opções desejadas no Vega ou nas
Configurações do GNOME. O auxiliar de migração
[`lyra-os-apply-full-theme`](src/defaults/lyra-os-apply-full-theme) já é executado
pelo pacote na atualização e no login. Seu alcance é a migração de seleções
GTK/Shell antigas do Lyra e a integração dos ícones com a cor de destaque;
ele não restaura um retrato completo da sessão anterior. CSS independente,
temas de terceiros e backups que não possam ser restaurados com segurança
são preservados. Não use um reset geral de dconf nem remova arquivos de
`/usr/share` manualmente para tentar reproduzir o antigo rollback.

GRUB, Plymouth e GDM pertencem ao ciclo do RPM. Uma eventual remoção do pacote
deve ser revisada no gerenciador de pacotes, inclusive suas dependências.
Os scripts do RPM tentam restaurar o tema anterior de GRUB/Plymouth quando o
Lyra ainda está selecionado e existe o backup correspondente, e retiram a
configuração de GDM criada pelo pacote. Isso não recupera personalizações de
sessões anteriores nem garante a restauração de uma instalação local antiga
sem inventário ou backup. Esta correção apenas retira o atalho inválido; não
executa remoção de pacotes, migração de preferências ou alterações de boot.

## Build e testes

```bash
./scripts/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
rpmbuild -bb packaging/lyra-os-theme.spec
```

O build requer `rsvg-convert` e Cantarell. A integração de sessão usa Python 3
e PyGObject. O nome `lyra-os-apply-full-theme` permanece por compatibilidade
com atualizações anteriores; a entrada de autostart o executa com `--watch`.

A suíte também verifica a existência e a permissão de execução dos scripts
locais referenciados por caminhos `./scripts/…` e `$root/…` nos scripts,
documentação, specs e workflows. A checagem é estática: não executa
instaladores ou rotinas administrativas.

O wallpaper padrão do pacote é `/usr/share/backgrounds/lyra/2702-voyage.png`.
A imagem GNOME define `2702-dawn.png` como seu padrão inicial.
