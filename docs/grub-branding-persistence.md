# GRUB-04: persistência na atualização do branding openSUSE

Em 25/09/2026, a estação voltou ao tema openSUSE porque uma atribuição de
`GRUB_THEME` apareceu depois do include da preferência Lyra. O ativador oficial
reescreve as atribuições existentes; se não encontrar uma, acrescenta outra
ao final. A correção mantém uma atribuição antes do include, que fica por último.

O arquivo `/etc/default/grub.lyra-theme` pertence ao RPM e usa
`%config(noreplace)`, preservando escolhas locais durante upgrades. Os dois
specs e o instalador manual usam a mesma ordem. Na remoção, o include é retirado
antes da regeneração do GRUB, mesmo quando o ativador já reescreveu a atribuição
anterior. O backup da primeira instalação continua sendo usado na restauração.

## Validação

`tests/test_grub_branding.py` executa os trechos GRUB dos scriptlets de ambos
os specs em diretórios temporários. O gerador é um stub que registra o tema
efetivo; estes testes não geram nem qualificam um menu inicializável.

A fixture `tests/fixtures/opensuse-activate-theme` é uma cópia do arquivo
`/usr/share/grub2/themes/openSUSE/activate-theme` do RPM oficial
`grub2-branding-openSUSE-16.1.20260917-lp161.1.1.noarch`.
SHA256: `befe2905707ed0255b37f309a509063f5f53a8a5dc00b9751535868b78d5fa64`.
O teste troca seus três diretórios de operação por caminhos temporários antes
de executar o Perl original. Não executá-la diretamente no host.

Cenários: instalação, duas ativações openSUSE consecutivas, upgrade Lyra,
preservação do backup e de parâmetros alheios ao tema, preferência personalizada
ou vazia, preferência ausente, ausência de configuração GRUB, remoção depois
da ativação openSUSE e instalador manual. O CI também constrói o RPM do tema.

## Limites e reversão

O ensaio não cobre substituição integral de `/etc/default/grub`, RPM final no
OBS ou boot da candidata. Esses gates devem ser registrados separadamente no
tracker do Desktop. Não aplicar scripts de teste ao host e não encerrar GRUB-04
com os testes de fontes.

Em regressão, interromper a promoção e corrigir pelo staging. Para a preferência
local, selecionar outro tema no arquivo próprio e regenerar o GRUB pelo fluxo
normal da distribuição. Remover o pacote também altera Plymouth/GDM; não é a
ação recomendada para trocar apenas o tema do menu.
