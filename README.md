# Veille IA automatisee avec n8n

Un workflow n8n qui fait une veille technologique sur l'IA, sans intervention manuelle.

Il lit des flux RSS publics, ecarte ce qu'il a deja vu, demande a un modele de langage
un resume en francais et une note de pertinence, puis ecrit le tout dans des fichiers
Markdown et CSV verifiables en local.

## Ce que fait le workflow

1. Deux declencheurs: un manuel (pour tester) et un planifie (toutes les 6 heures).
2. Lecture de trois flux RSS publics:
   - Blog Hugging Face: `https://huggingface.co/blog/feed.xml`
   - arXiv cs.AI: `https://export.arxiv.org/rss/cs.AI`
   - MIT Technology Review (IA): `https://www.technologyreview.com/topic/artificial-intelligence/feed/`
3. Normalisation des items. On garde les plus recents par flux (8 au maximum).
   Si un flux est vide a un instant donne, le workflow continue avec les autres.
4. Deduplication contre un fichier d'etat `data/seen.json`. Un item deja traite est ignore.
5. Pour chaque nouvel item, un appel a l'API d'inference Hugging Face (modele Qwen instruct,
   endpoint compatible OpenAI). Le modele renvoie un JSON: un resume court en francais,
   un tag, une note de 1 a 5.
6. Ecriture des resultats dans `data/veille.md` et `data/veille.csv` en mode ajout.

## Stack

- n8n (image officielle `n8nio/n8n`).
- API d'inference Hugging Face, endpoint compatible OpenAI:
  `https://router.huggingface.co/v1/chat/completions`.
- Modele: `Qwen/Qwen2.5-Coder-32B-Instruct` (servi par le routeur Hugging Face).
- Conteneur lance avec podman ou docker.

## Prerequis

- podman ou docker installe.
- Un token Hugging Face (acces lecture suffit), depuis
  `https://huggingface.co/settings/tokens`.

## Etapes pour lancer

1. Copier le modele d'environnement et mettre votre token:

   ```bash
   cp .env.example .env
   # editer .env et remplacer hf_xxx par votre token
   ```

2. Exporter le token dans le shell, puis demarrer n8n et importer le workflow:

   ```bash
   export HF_TOKEN=hf_xxx
   ./run.sh up
   ```

   Le script cree le conteneur, monte le dossier `data/` et importe
   `workflows/veille-ia.json`. L'interface est sur `http://localhost:5678`.

   Variante docker compose:

   ```bash
   export HF_TOKEN=hf_xxx
   docker compose up -d
   docker compose exec n8n n8n import:workflow --input=/workflows/veille-ia.json
   ```

3. Creer la credential du token dans n8n (une seule fois):
   - Ouvrir `http://localhost:5678`.
   - Aller dans Credentials, creer une credential de type "Header Auth".
   - Nom de l'en-tete: `Authorization`. Valeur: `Bearer VOTRE_TOKEN`.
   - Dans le workflow, ouvrir le noeud "Appel LLM Hugging Face" et selectionner
     cette credential.

   Le workflow reference une credential nommee "HF router token". Si vous gardez ce nom,
   n8n la relie automatiquement.

4. Lancer une execution:
   - Ouvrir le workflow "Veille IA automatisee".
   - Cliquer sur "Test workflow" (ou activer le workflow pour le mode planifie).

5. Verifier la sortie cote hote:

   ```bash
   cat data/veille.md
   cat data/veille.csv
   ```

## Note sur les noeuds Code et l'ecriture de fichiers

Les noeuds Code ecrivent dans `/data` avec le module Node `fs`. n8n n'autorise ce module
que si la variable `NODE_FUNCTION_ALLOW_BUILTIN=fs` est definie. Le compose et `run.sh`
la definissent deja.

## Verification headless (sans interface)

Le workflow a ete teste en mode headless avec la commande `n8n execute`. Pour ce test,
le depot fournit une variante `workflows/veille-ia-headless.json` identique au workflow
principal, sauf que le noeud HTTP lit le token depuis la variable d'environnement
`HF_TOKEN` au lieu d'une credential. Cela evite de creer une credential a la main pour
le test. Pour reproduire:

```bash
export HF_TOKEN=hf_xxx
mkdir -p data n8n-data

# 1. Importer la variante headless
podman run --rm --userns=keep-id \
  -v "$(pwd)/n8n-data:/home/node/.n8n:Z" \
  -v "$(pwd)/workflows:/workflows:ro,Z" \
  n8nio/n8n:latest \
  import:workflow --input=/workflows/veille-ia-headless.json

# 2. L'executer
podman run --rm --userns=keep-id \
  -e NODE_FUNCTION_ALLOW_BUILTIN=fs \
  -e N8N_BLOCK_ENV_ACCESS_IN_NODE=false \
  -e HF_TOKEN="$HF_TOKEN" \
  -e N8N_RUNNERS_ENABLED=false \
  -v "$(pwd)/n8n-data:/home/node/.n8n:Z" \
  -v "$(pwd)/data:/data:Z" \
  n8nio/n8n:latest \
  execute --id=veilleiahdless01

cat data/veille.md
```

Note pour podman en mode rootless: le drapeau `--userns=keep-id` est important pour que
les fichiers ecrits dans les volumes montes appartiennent au bon utilisateur.

La variable `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` n'est utile que pour ce test headless,
quand on lit le token via une expression `$env`. En usage normal par l'interface,
on passe par une credential et cette variable n'est pas necessaire.

## Ce que ca a produit

Voir le dossier `examples/`. Il contient une sortie reelle produite par une execution
contre les vrais flux RSS le 2026-06-21, avec les vrais resumes generes par le modele.
Le run a produit 16 articles resumes (8 du blog Hugging Face, 8 de MIT Technology Review).
Une seconde execution n'a rien ajoute, ce qui confirme la deduplication.

## Ce que Sami doit configurer

- Mettre un vrai token Hugging Face dans `.env` et dans la credential n8n.
- Le token n'est jamais committe. `.env` est dans `.gitignore`.
- Optionnel: changer les flux RSS ou la frequence du declencheur planifie.
- Optionnel: ajouter un envoi vers un webhook Discord en bout de workflow.

## Note sur les couts

L'API d'inference Hugging Face peut etre limitee ou facturee selon le compte et le modele.
Le workflow ne traite que quelques items par execution pour rester sobre.
