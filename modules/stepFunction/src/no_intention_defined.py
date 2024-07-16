import json

from custom_methods import slack_bot_response


def handler(event, context):
    if "errorInfo" in event:
        slack_bot_response("Uuuuuu Panie kochany :( coś nie poszło.... ")
        slack_bot_response(event)
    else:
        slack_bot_response("Sorki ale nie wiem o co ci chodzi :( ")


