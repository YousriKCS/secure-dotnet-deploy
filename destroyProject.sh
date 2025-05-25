#!/bin/bash

# Krijg de lijst van actieve projecten
echo "Lijst van Google Cloud projecten ophalen..."
PROJECT_LIST=$(gcloud projects list --format="value(projectId)")

echo "Beschikbare projecten:"
echo "$PROJECT_LIST"

# Vraag de gebruiker om een project te selecteren (of gebruik automatisch een project)
echo "Geef de project-ID in die je wilt verwijderen (of druk op Enter om het eerste project te gebruiken):"
read SELECTED_PROJECT

# Als er geen project is ingevoerd, gebruik dan het eerste project uit de lijst
if [ -z "$SELECTED_PROJECT" ]; then
  SELECTED_PROJECT=$(echo "$PROJECT_LIST" | head -n 1)
fi

echo "Geselecteerd project: $SELECTED_PROJECT"

# Zet het geselecteerde project in de actieve configuratie
gcloud config set project $SELECTED_PROJECT

# Verwijder het project
echo "Verwijderen van project $SELECTED_PROJECT..."
gcloud projects delete $SELECTED_PROJECT --quiet

# Controleer of het project is verwijderd
if [ $? -eq 0 ]; then
    echo "✅ Project $SELECTED_PROJECT is succesvol verwijderd!"
else
    echo "❌ Er is een fout opgetreden bij het verwijderen van het project $SELECTED_PROJECT."
fi
