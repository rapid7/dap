bzcat http_get_reply_iframes.json.bz2 | ../bin/dap json + transform data=base64decode + html_links data + select ip link element + decode_uri link + json
