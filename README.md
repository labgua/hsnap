# hsnap

## Introduzione

hsnap è un tool ed un insieme di utility che aiuta a creare e gestire snapshot incrementali di progetti PHP su comuni servizi hosting.

## Quick Start

Apri il tuo progetto git, incolla nella cartella i file del progetto.

Configura lo script inserendo i parametri nel file di configurazione `.conf.snapshot` :

```bash
# url sito web 
SS_HOST="https://host.domain.com"

# credenziali ftp
# host, porta, username, password
SS_FTP_HOST="ftphost.domain.com"
SS_FTP_PORT="21"
SS_USER="username_ftp"
SS_PASS="password_ftp"

# path del progetto da controllare
SS_PATH="/path/of/project/"

# credenziali per rpc
# secret, path in cui installare il server rpc
SS_SECRET="MAGICSECRET"
SS_PATH_RPC="/path/to/rpc/"
```

Inizializza il progetto con:

```bash
$ ./snapshot.sh init
```

Installa il server rpc con il comando:

```bash
$ ./snapshot.sh install_rpc
```

Ora effettua tutte le tue modifiche creando gli opportuni commit.

Ogni volta che vuoi caricare le variazioni fino al commit COMMIT_ID in remoto utilizza il comando:

```bash
$ ./snapshot.sh update COMMIT_ID OUTZIP.zip
``` 

Per poter annullare le modifiche e tornare ad un partcolare commit COMMIT_ID puoi eseguire il comando:

```bash
$ ./snapshot.sh revert COMMIT_ID OUTZIP.zip
```


## Documentazione

### Snapshot

Lo snapshot rappresenta le variazione del progetto da uno stato ad un altro in termini di codice, quindi l'insieme di aggiunte, modifiche e cancellazioni per poter passare da uno stato all'altro.
In sostanza uno snapshot è la differenza tra due commit di un progetto git, in altre parole una semplificazione del concetto di patch.

### Perchè non utilizzare git

La necessità di dover utilizzare uno strumento che non sia git nasce dal fatto che su servizi di hosting spesso non è possibile poter utilizzare git o altri programmi di basso livello.
Gli unici servizi resi disponibili sono FTP e brevi computazioni di poca memoria.

Lo scopo è quello di sfruttare i meccanismi di FTP e CGI per poter creare snapshot locali da poter applicare in remoto.