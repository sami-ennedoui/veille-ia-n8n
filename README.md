# Veille IA automatisee avec n8n

Un workflow n8n qui fait une veille technologique sur l'IA, sans intervention manuelle.

Il lit des flux RSS publics, ecarte ce qu'il a deja vu, demande a un modele de langage
un resume en francais et une note de pertinence, puis ecrit le tout dans des fichiers
Markdown et CSV verifiables en local.

## Ce que fait le workflow

1. Deux declencheurs: un manuel (pour tester) et un planifie (toutes les 6 heures).
2. Lecture de deux flux RSS publics:
   - Blog Hugging Face: `https://huggingface.co/blog/feed.xml`
   - arXiv cs.AI: `https://export.arxiv.org/rss/cs.AI`
3. Fusion et normalisation des items. On garde les 6 plus recents.
4. Deduplication contre un fichier d'etat `data/seen.json`. Un item deja traite est ignore.
5. Pour chaque nouvel item, un appel a l'API d'inference Hugging Face (modele Qwen instruct).
   Le modele renvoie un JSON: un resume court en francais, un tag, une note de 1 a 5.
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

## Ce que ca a produit

Voir le dossier `examples/`. Il contient une sortie reelle produite par une execution
contre les vrais flux RSS, avec les vrais resumes generes par le modele.

## Ce que Sami doit configurer

- Mettre un vrai token Hugging Face dans `.env` et dans la credential n8n.
- Le token n'est jamais committe. `.env` est dans `.gitignore`.
- Optionnel: changer les flux RSS ou la frequence du declencheur planifie.
- Optionnel: ajouter un envoi vers un webhook Discord en bout de workflow.

## Note sur les couts

L'API d'inference Hugging Face peut etre limitee ou facturee selon le compte et le modele.
Le workflow ne traite que quelques items par execution pour rester sobre.
