# To install dependency for python lambda layer: 

first move to:

>cd modules\api\src\langchain_openAI_lambda_layer

then add desired dependencies to the __requirements.txt__  and run:

> pip install --platform manylinux2014_x86_64 --only-binary=:all: -r requirements.txt -t layer\python\lib\python3.12\site-packages

to install serpapi with google use in addition to above:  

> pip install google-search-results -t layer\python\lib\python3.12\site-packages


# activate Python virtual env

> .\jarvan\Scripts\activate

