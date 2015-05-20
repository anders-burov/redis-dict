ssh-keygen -t rsa
ssh-keygen -f id_rsa.pub -e -m PKCS8 > id_rsa.pem.pub
openssl rsautl -encrypt -pubin -inkey id_rsa.pem.pub -ssl -in MyMessage.txt -out MyEncryptedMessage.txt
openssl rsautl -decrypt -inkey id_rsa -in MyEncryptedMessage.txt -out MyDecryptedMessage.txt
