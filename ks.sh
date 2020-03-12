SERVER=$1
curl -s "https://${SERVER}/pks/lookup?search=0x865A0B217CA5AC14&exact=on&options=mr&op=get"

curl -s "https://${SERVER}/pks/lookup?search=0x865A0B217CA5AC14&op=get"