# To install dependency for python lambda layer: 

first move to:

>cd modules\api\src\lambda_layer_dependencies

then add desired dependencies to the __requirements.txt__  and run:

> pip install --platform manylinux2014_x86_64 --only-binary=:all: -r requirements.txt -t python\python\lib\python3.12\site-packages

to install ser api with google use in addition to above:  

> pip install google-search-results -t python\python\lib\python3.12\site-packages


right now you have to pack folder python by yourself 


# Set  keys for windows: 

> set TF_VAR_openAIKey=

> set TF_VAR_serpAPIKey=

# activate Python virtual env

> .\jarvan\Scripts\activate

