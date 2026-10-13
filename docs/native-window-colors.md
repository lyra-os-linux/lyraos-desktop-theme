# Cores Lyra nas janelas nativas

Integração opcional por usuário, com paletas clara e escura derivadas do
Firefox Lyra. Os controles e a geometria Adwaita são preservados.

```sh
lyra-native-colors --install
```

Execute sem sudo, na sessão GNOME. A instalação copia o auxiliar e as paletas
para `~/.local/share/lyra-native-colors`, instala os temas GTK 3 por usuário e
habilita `lyra-native-colors.service` na sessão gráfica. O funcionamento não
depende de manter o checkout Git no mesmo lugar.

Depois, alterne claro/escuro nas Configurações do GNOME ou no Vega. GTK 4 /
libadwaita adapta suas cores dentro do aplicativo, inclusive se ele escolher
seu próprio modo. O serviço acompanha `color-scheme`, seleciona a variante
GTK 3 e sincroniza fundo, texto e 16 cores ANSI do perfil padrão do Terminal.
Fontes, comandos, histórico e demais perfis não são alterados. Console e
Terminal são inicialmente configurados para seguir o sistema; uma alteração
posterior nessas preferências próprias é preservada.

Quando a extensão GNOME User Themes está disponível, o mesmo serviço seleciona
uma folha de estilo Lyra clara ou escura para os diálogos modais do GNOME Shell,
incluindo prompts do polkit. O CSS não altera painel, menus nem a lógica de
autenticação. A preferência de tema Shell anterior é restaurada com `--undo`;
se o usuário escolher outro tema depois da ativação, essa escolha é preservada.

É preciso reabrir **uma vez** os aplicativos que ainda carreguem o antigo CSS
fixo. Depois disso, a alternância acontece com as janelas abertas. O auxiliar
não encerra aplicativos nem sessões de terminal.

## Correções de integração

O protótipo anterior gravava cores fixas no CSS do usuário. Além de não
acompanhar a mudança de modo, a regra `.background` tinha prioridade maior
que a transparência da janela de ícones e escondia o papel de parede.

GTK 3 agora usa temas que importam Adwaita na prioridade normal de tema,
abaixo do CSS do aplicativo. A janela `desktopwindow` mantém fundo transparente.
A imagem e as preferências de papel de parede não são modificadas.
GTK 4 usa variáveis de cor e não regras para pintar janelas genéricas.

A paleta GTK 4 acompanha `--standalone-color-oklab`, que o libadwaita 1.7
alterna entre `min(l, .5) a b` e `max(l, .85) a b`. Esse contrato permite
selecionar as cores Lyra com expressões relativas Oklab sem reescrever CSS
nem reiniciar o aplicativo. Deve ser requalificado ao atualizar o libadwaita.
Referência: [variáveis do libadwaita](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.6/css-variables.html).

O Console mantém sua paleta interna original. O Console 48.0.1 distribuído
na Leap 16.1 tem um erro no leitor `custom-liveries`: interpreta uma entrada
`{sv}` como tupla `(sv)`. Não gravamos essa configuração defeituosa nem
alteramos o executável. Referência do
[leitor upstream](https://github.com/GNOME/console/blob/48.0.1/src/kgx-livery-manager.c#L307).

## Reversão e limites

```sh
lyra-native-colors --undo
```

A reversão desativa o serviço e restaura as preferências e arquivos registrados
em `~/.local/state/lyra-os-theme/native-colors.json`. Alterações posteriores do
usuário são preservadas e reportadas; o backup permanece para esses conflitos.
CSS independente e links de gerenciadores de temas não são substituídos
silenciosamente. Para migrar do protótipo fixo, execute primeiro `--undo` com
seu backup original e depois `--install`.

Antes de usar alto contraste, desfaça esta personalização; a instalação é
recusada quando alto contraste já está ativo. A interação completa com alto
contraste ainda não está qualificada. Flatpaks conservam suas permissões de
sandbox, sem concessão adicional de acesso ao tema.

O comando é distribuído no RPM lyra-os-theme 1.10.0. A ativação é por usuário;
o autostart atualiza somente uma personalização já ativada com serviço
habilitado e unidade ainda gerenciada. Não ativa a paleta em novos perfis nem
reativa um serviço desabilitado pelo usuário. GNOME Shell e configurações de
papel de parede não são alterados. Os scripts de boot do pacote são preservados.

## Validação

GTK 4.18.6 / libadwaita 1.7.5 e GTK 3 da Leap 16.1, em compositor Mutter,
D-Bus, portais GNOME e configurações temporárias:

- Nautilus, Console e Terminal permanecem no mesmo processo durante as
  trocas escuro → claro → escuro, com captura e checagem dos pixels;
- sincronização das preferências reais do GNOME pelo auxiliar de sessão;
- janela GTK 3 com a classe e o CSS reais dos ícones preserva alfa zero em
  claro → escuro → claro; a regra antiga reproduz alfa opaco;
- reaplicação e reversão preservam CSS anterior.

Isso não qualifica todos os aplicativos GTK nem uma ISO candidata.
