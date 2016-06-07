===================
Release Git Version
===================

Ferramenta para automatizar a liberação de versões com Git.

GERAR VERSÃO NO GIT DE FORMA AUTOMATIZADA
-----------------------------------------

URL do repositorio GIT: http://alm.agu.gov.br/tfs/DTI/Projetos/_git/Intranet
Numero da nova versao: 2.0.0
Branch de versao [2.0.0rc]:
Branch de producao [master]:
Branch de desenvolvimento [develop]:
Nome do arquivo CHANGELOG [ChangeLog.txt]:
Nome do arquivo VERSAO [versao.txt]:
Nome do remoto para versão [origin]:
Prefixo de tag [v]:
Usuario responsável [$git config user.name]:
E-mail do usuario responsável [$git config user.email]:
 * Tag a gerar [v2.0.0]
 * Numero da versão [2.0.0]
 * Log da geração de versão [tmpname_v2.0.0.log]
 * Arquivo CHANGELOG do merge [tmpname_{CHANGELOG}]
 * Arquivo CHANGELOG stage [tmpname_stage_{CHANGELOG}]
 * Diretorio temporario para operacoes [tmpname]

Adicionar um trabalho (branch/commit)? issue/3785
Commit com mensagem de log [ultimo]:
 * branches para merge [
     {"issue/3785",""}
   ]

Adicionar mais um trabalho (branch/commit)? sd56f4ds456e465ds
Commit com mensagem de log [ultimo]:
 * branches para merge [
     {"issue/3785":""},
     {"sd56f4ds456e465ds",""}
   ]
 
Adicionar mais um trabalho (branch/commit)? bug-1234
Commit com mensagem de log [ultimo]: sd45f4d4d54fs46df456d45df654fd465
 * branches para merge [
     {"issue/3785",""},
     {"sd56f4ds456e465ds",""},
     {"bug-1234","sd45f4d4d54fs46df456d45df654fd465"}
   ]
 
1. Clona o repositorio em "diretorio_temporario/repository"
 
2. Se branch de versão já existe, ERRO;
   Grava "Erro: Branch de versão [2.0.0rc] já existe" >> "tmpname_v2.0.0.log"
3. Se branch de produção NÃO existe, ERRO;
   Grava "Erro: Branch de produção [master] não existe" >> "tmpname_v2.0.0.log"
4. Se tag a gerar já existe, ERRO;
   Grava "Erro: Tag [v2.0.0] já existe" >> "tmpname_v2.0.0.log"
5. Se algum branch para merge não existe, ERRO;
   Grava "Erro: Branch de trabalho[X] não existe" >> "tmpname_v2.0.0.log"

6. Configura dados de usuário
   $ git config user.name {nome_usuario}
   $ git config user.email {email_usuario}
   
7. Muda para "branch de produção"
   $ git checkout master

8. Gerar branch de versão
   $ git checkout -b 2.0.0rc

9. Para cada branch de merge:
9.1. Grava "Merge de {remoto}/{branch de merge}\n--------" >> "tmpname_v2.0.0.log"
9.2. Faz merge no branch de versão:
     $ git merge "{remoto}/{branch de merge}" >> "tmpname_v2.0.0.log"
9.3. Grava LOG de "$git log -1 --no-merges --pretty=oneline|foreach($git log -10 --no-merges --pretty=oneline)" >> "tmpname_{CHANGELOG}"
     # commits de merges não são considerados
     # No caso de buscar uma mensagem de um commit específico, só serão considerados os 10 ultimos comits
     #  - Não sendo possível ser encontrado nenhum, será considerado o último
9.4. Se falhar, ERRO;
     Grava "Erro: Não foi possível fazer merge de {branch de merge} para {2.0.0rc}" >> "tmpname_v2.0.0.log"

10. Escreve número de versão
    $ Grava "2.0.0" >> "versao.txt"
11. Escreve CHANGELOG
    $ Grava "2.0.0" > "tmpname_stage_{CHANGELOG}"
    $ Grava "=====" >> "tmpname_stage_{CHANGELOG}"
    $ Grava "[tmpname_{CHANGELOG}]" >> "tmpname_stage_{CHANGELOG}"
    $ Grava "" >> "tmpname_stage_{CHANGELOG}"
    $ Grava "[ChangeLog.txt]" >> "tmpname_stage_{CHANGELOG}"
    $ Grava "[tmpname_stage_{CHANGELOG}]" > "[ChangeLog.txt]"

12. Comita as alterações em "versao.txt" e "ChangeLog.txt"
    $ git add --force "versao.txt"
    $ git add --force "ChangeLog.txt"
    $ git commit -m "Dados da versão [2.0.0] atualizados em 'versao.txt' e 'ChangeLog.txt'"

13. Gerar TAG de versão
    $ git tag "v2.0.0"

14. Merge em DEVELOP
    $ git checkout "develop"
    $ git merge "v2.0.0"
14.1. Se falhar, ERRO;
    Grava "Erro: Não foi possível fazer merge de {v2.0.0} para {develop}" >> "tmpname_v2.0.0.log"

15. Exibir mensagem de sucesso, apresentar caminho do arquivo de LOG e caminho da pasta temporária do repositório

16. Deseja enviar versão para servidor remoto agora?
    Se sim:
        $ git push -u {remoto} {master}:{master}
        $ git push -u {remoto} {develop}:{develop}
        $ git push -u {remoto} {v2.0.0}:{v2.0.0}
    Se não:
        Imprimir necessidade de fazer push de {master, develop, v2.0.0} para {origin}
        $ explorer {pasta_tmp}/repository
