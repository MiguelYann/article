# Notes


# Deploy to Azure

* Azure Container Registry is your private Docker registry in Azure. In this tutorial, part two of the series, you:

Prerequis

* Installer une Azure CLI

```

```

* Se connecter a son compte Azure
 *  Veuillez vous assurer que vous etes inclu à l'abonnement fait par l'admin
 [Comment rajouter un utilisateur à un abonnement](https://docs.microsoft.com/fr-fr/azure/cost-management-billing/manage/add-change-subscription-administrator)

```shell
az login
```

On sera redirigé vers le navigateur ou on pourra se logguer.
> CloudShell n'est pas utilisable vu qu'il n'a pas Docker daemon

* Creer un RG

```shell
az group create --name myResourceGroup --location eastus
```

Si tout s'est bien passé, vous aurez un fichier au format JSON qui apparaitra dans le terminal.

### __________ACR Push image______

* Creer une instance de ACR, service qui conserve les images Docker

```shell
az acr create --resource-group myResourceGroup --name <acrName> --sku Basic
```
🚦 Le nom de votre Acr doit etre DNS Compliant, trouver donc un nom unique

Si tout se passe bien, vous aurez un fichier au format JSON qui apparaitra dans le terminal.

* **Avant de pousser notre image dans le regisrty, on doit se connecter à lui**
        - docker login -u "$ACR_TOKEN_NAME" -p "$ACR_TOKEN" "$ACR_URL"

```shell
az acr login --name <acrName>
        az login --service-principal --username "$SERVICE_PRINCIPAL_ID" --password "$SERVICE_PRINCIPAL_PASSWORD"

```
Si l'authentification s'est bien déroulée vous aurez un message indiquant que vous etes bien connecté a votre serveur ACR.


* Pour pousser une image dans ACR, on doit taguer notre image avec le serveur d'authentification du registry

    * Obtenir le nom complet du serveur d'authentification de notre ACR
 ```shell
az acr show --name mycontainerregistry082 --query loginServer --output table 
```

On obtient donc le nom complet du serveur d'auth: *mytregistry1.azurecr.io*


*  **Taguer ton image, avec le serveur d'authentification**

Ceci suppose que vous avez déjà builder votre image Docker

```shell
docker build -t <imageDockerName> <cheminVersLeDockerFile>
```
```shell
docker tag <imageDockerName> <acrLoginServer>/<imageDockerName>:<tag>
```
> Nous recommandons de commencer par V1.0.0


* **Pusher notre image dans notre registry privé**

```shell
docker push <acrLoginServer>/<imageDocker>:<tag>
```
> Cela peut prendre un peu de temps; dependemment de la connexion Internet

* Verifier la liste des images enregistées dans notre ACR

```shell
az acr repository list --name <acrName> --output table
```

Nous devrions voir notre image apparaitre dans la console.

* Pour voir les tags pour une image spécifique 

```shell
az acr repository show-tags --name <acrName> --repository <imageDocker> --output table  
```

### Deploy container to Azure Container Instances

**Azure Container Instances** est le service aui permet de runner nos containers, et donc de gérer nos containers. Il prendra les images issues de notre Registry

* Recuperer les credentials du registry

Notre registry est privé, donc pour avoir accès à nos images, nous devons fournir des credentials pour y accéder.

Pour cela la meilleur pratique est de creer un Service Principal de AAD avec les permissions Pull sur notre Registry privé.

> On utilise le service principal quand une app, un service ou un script a besoin d'acceder aux données d'un autre, avec des permissions précises.

> On peut specifier le role pour les permissions a la creation du service principal

```shell
#!/bin/bash

# Modify for your environment.
# ACR_NAME: The name of your Azure Container Registry
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
ACR_NAME=<container-registry-name>
SERVICE_PRINCIPAL_NAME=acr-service-principal

# Obtain the full registry ID for subsequent command args
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)

# Create the service principal with rights scoped to the registry.
# Default permissions are for docker pull access. Modify the '--role'
# argument value as desired:
# acrpull:     pull only
# acrpush:     push and pull
# owner:       push, pull, and assign roles
SP_PASSWD=$(az ad sp create-for-rbac --name http://$SERVICE_PRINCIPAL_NAME --scopes $ACR_REGISTRY_ID --role acrpull --query password --output tsv)
SP_APP_ID=$(az ad sp show --id http://$SERVICE_PRINCIPAL_NAME --query appId --output tsv)

# Output the service principal's credentials; use these in your services and
# applications to authenticate to the container registry.
echo "Service principal ID: $SP_APP_ID"
echo "Service principal password: $SP_PASSWD"
```

🥺ISSUE [Error on az ad sp create-for-rbac #24857](https://github.com/MicrosoftDocs/azure-docs/issues/24857) OBLIGER D'UTILISER CLOUD SHELL, pour le génerer.

#### Accéder à CloudShell

C'est un interface en ligne de commande accessible depuis un navigateur; qui vous fournit un Shell, un Powershell avec la CLI Azure déjà préinstallé.

* Depuis le portail Azure, dans la barre de navigation, vous trouverez sur la barre de navigation, juste à la droite de la barre de recherche une icon qui vous permettra d'accéder à CloudShell, cliquer dessus.

![cloudShell](./src/assets/cloudShell.png)

* Il vous sera demandé de creer **un compte de stockage**, il sert à stocker toutes les données que vous aller creer dans les sessions dans CLoudShell, car une fois une session CloudShell fermée, les données seront perdues. La création se fait juste en cliquant sur le bouton ``Creer..``, cela peut prendre quelques instants, une fois crée, vous allez avoir accès à un shell(Bash/Powershell). Vous pouvez naviguer entre les 2.

* Cette manipulation que nous allons faire, est tout simplement du au fait que la CLI d'Azure a des problèmes avec le shell fournit par Gitbash.

* Creer dans CloudShell, un fichier de script avec un nombre de votre choix. Example: ``scriptAcr.sh``
```shell
vim scriptAcr.sh
```
Ceci permettra de créer le fichier et de l'éditer directement. Entrer ``i`` pour insérer du texte dans notre fichier(ceci est propre à Vim). 

* Copier le contenu du fichier de script ``generate_credentials_sp_acr.sh`` contenu dans le repertoire ``azure_configuration/scripts``

* Coller le contenu de ce fichier dans le fichier crée sur CloudShell. Sauvegarder le fichier.

* Executer le script en question

```shell
bash scriptAcr.sh
```

Si tout s'est bien passé, vous aurez dans la console, le ``servicePrincipalId`` et le ``servicePrincipalPassword``

Examples: 
* 🔑 ServicePrincipalID: 2f59c3ff-094e-44b9-908d-70e28d43eaaf
* 🗝 ServicePrincipalPasswd: 2bSMyGui_.2HbRl8LHoATls9qbar2gpf6f


#### Deploy images(container)

Pour deployer on doit creer une instance de ACI, en s'authentifiant avec notre service principal
pour acceder à nos images dans notre registry privé créer prédemment.

* Aller dans le fichier ``create_aci_instance.sh`` contenu dans le repertoire du projet ``azure_configuration/scripts``
* Renseigner les variables avec les bonnes valeurs



```shell
az container create \
    --resource-group myResourceGroup \
    --name <nomDeLinstanceACI> \
    --image <mytregistry1.azurecr.io/myimg:v1> \
     --dns-name-label <nomDedomaine> \
    --ports <PORT> \
    --registry-login-server <mytregistry1.azurecr.io> \
    --registry-username <serviceprincipalId> \
    --registry-password <servicePrincipalPwd>
```
* Verifier la progression du deploiement

```shell
az container show --resource-group <resourceGroupName> --name <nomDeLinstanceACI> --query instanceView.state
```
Si le process de déploiement est bien effectué, on aura un output ``Running``.

Notre container est a présent bien déployer sur une instance ACI qui s'est chargé de le lancer, à partir de notre image stockée dans le Registy.😊

Nous avons renseigné un nom de domaine précedemment. Il servira à accéder à notre application.

* Recuperer le FQDN Full qualified domain name du container, pour accéder à notre application

```shell
az container show --resource-group <resourceGroupName> --name <nomDeLinstanceACI> --query ipAddress.fqdn
```

Un exemple d'Output: ``"sandbox.eastus.azurecontainer.io"``

L'application est déployé et accessible via ``sandbox.eastus.azurecontainer.io``


### Preparer une release

* Builder le projet en local
* Builder une nouvelle image avec le meme nom que l'image de base
Sachant qu'elle va ecraser l'ancienne image, pas de panique.
* Tagguer l'image si tout est OK, avec le serveur ACR et le numero du tag de la meme image tagguer que precedemment

En effet elle sera aussi écrasé. Mais nous avons une version dans le registry qu'on pourra récuperer à tout moment. 😉
* Pusher cette image tagguer dans le registry. En executant le script(ceci suppose que vous etes biensur connecté au registry)

```shell
docker push <acrLoginServer>/<imageDocker>:<tag>
```

🚨 Une erreur d'authentification peut apparaitre avec cette commande

* AJOUTER L'application dans le RBAC de la soubscription en Owner

#### Quelques solutions à entreprendre

* Aller dans le registry et rajouter le ROLE ``OWNER`` ou ``CONTRIBUTOR`` à l'utilisateur
* Se connecter via Docker directement
* Azure et Docker ne sont pas synchrones parfois la configuration de Docker a des soucis sur votre poste
* Génerer un token à la connexion de votre registry, qui nous permettra de nous connecter via Docker

```shell
az acr login --expose-token
```
En sortie nous aurons un username et un password générer par Azure pour nous pour qu'on puisse se connecter

* Se connecter avec Docker

```shell
docker login <serveurRegistry>:443 --username <usernameAzureGenere> --password <passwordAzureGenere>
```

* Reessayer de pusher votre image avec Docker à présent, cela devrait fonctionner

* Verifier que le tag est ajoutée à votre image 

```shell
az acr repository show-tags --name <nameRegistryACR> --repository imgsand --output table
```

Il est possible via le portail Azure également de le vérifier.

``HOME/NOM_REGISTRY/IMAGE_NAME``

* Modifier le tag dans le fichier de la CI de Gitlab(primordial pour lancer le pipeline avec la bonne version du tag, vu qu'elle se passe sur celui-ci), et dans le fichier de Script ``create_aci_instance.sh`` contenu dans le repertoire du projet ``azure_configuration/scripts``(Ceci est par soucis de synchronisation)

* Lancer le déploiement dans ACI(Automatique par la CI)


### A suivre

* Azure permet de déployer des containers en groupe. L'idée est d'avoir plusieurs containers qui partagent le meme systeme de fichier, un meme réseau et un seul DNS. Chaque container démarra sur un port spécifique. Une sorte de Kubernetes.

[Plus de détails sur les Container Group](https://docs.microsoft.com/fr-fr/azure/container-instances/container-instances-container-groups)








    