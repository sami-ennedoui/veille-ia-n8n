# Exemples de sortie reelle

Ce dossier contient une sortie reelle produite par une execution du workflow le 2026-06-21,
contre les vrais flux RSS, avec les vrais resumes generes par le modele Qwen via l'API
d'inference Hugging Face.

## Fichiers

- `veille.md`: les resultats en Markdown. 16 articles, 8 du blog Hugging Face et
  8 de MIT Technology Review. Chaque entree a un resume en francais, un tag et une note.
- `veille.csv`: les memes resultats en CSV (date, tag, pertinence, titre, lien, resume).
- `seen.json`: le fichier d'etat de deduplication. Il contient les ids deja traites.
- `exemple-reponse-llm.json`: une reponse brute de l'API Hugging Face, pour montrer
  le format exact renvoye par le modele (le champ `choices[0].message.content` contient
  le JSON resume, tag, pertinence).

## Verification de la deduplication

Une seconde execution juste apres la premiere n'a ajoute aucune ligne. Les ids etaient
deja dans `seen.json`, donc les articles ont ete ignores. C'est le comportement attendu.

## Note honnete

- Le flux arXiv cs.AI etait vide au moment de l'execution (un dimanche, arXiv ne publie pas).
  Le workflow a continue normalement avec les deux autres flux. C'est un cas reel gere proprement.
- Deux articles ont une pertinence de 0. Pour ces deux cas, le modele a renvoye la note dans un
  format que le parseur n'a pas pu convertir en entier, donc la valeur de repli 0 a ete utilisee.
  Le resume et le tag restent corrects.
