function base64Encode(text){

    if (/([^\u0000-\u00ff])/.test(text)){
        throw new Error("Can't base64 encode non-ASCII characters.");
    } 

    var digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
        i = 0,
        cur, prev, byteNum,
        result=[];      

    while(i < text.length){

        cur = text.charCodeAt(i);
        byteNum = i % 3;

        switch(byteNum){
            case 0: //first byte
                result.push(digits.charAt(cur >> 2));
                break;

            case 1: //second byte
                result.push(digits.charAt((prev & 3) << 4 | (cur >> 4)));
                break;

            case 2: //third byte
                result.push(digits.charAt((prev & 0x0f) << 2 | (cur >> 6)));
                result.push(digits.charAt(cur & 0x3f));
                break;
        }

        prev = cur;
        i++;
    }

    if (byteNum == 0){
        result.push(digits.charAt((prev & 3) << 4));
        result.push("==");
    } else if (byteNum == 1){
        result.push(digits.charAt((prev & 0x0f) << 2));
        result.push("=");
    }

    return result.join("");
}

function base64Decode(text){

    text = text.replace(/\s/g,"");

    if(!(/^[a-z0-9\-_\s]+\={0,2}$/i.test(text)) || text.length % 4 > 0){
        throw new Error("Not a base64-encoded string.");
    }   

    //local variables
    var digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        cur, prev, digitNum,
        i=0,
        result = [];

    text = text.replace(/=/g, "");

    while(i < text.length){

        cur = digits.indexOf(text.charAt(i));
        digitNum = i % 4;

        switch(digitNum){

            //case 0: first digit - do nothing, not enough info to work with

            case 1: //second digit
                result.push(String.fromCharCode(prev << 2 | cur >> 4));
                break;

            case 2: //third digit
                result.push(String.fromCharCode((prev & 0x0f) << 4 | cur >> 2));
                break;

            case 3: //fourth digit
                result.push(String.fromCharCode((prev & 3) << 6 | cur));
                break;
        }

        prev = cur;
        i++;
    }

    return result.join("");
}
