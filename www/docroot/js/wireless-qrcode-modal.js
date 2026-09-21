$(function() {

  //function to convert data with base64 image to Blob type
  function b64toBlob(b64Data, contentType, sliceSize) {
    contentType = contentType || '';
    sliceSize = sliceSize || 512;
    var byteCharacters = atob(b64Data);
    var byteArrays = [];
    for (var offset = 0; offset < byteCharacters.length; offset += sliceSize) {
      var slice = byteCharacters.slice(offset, offset + sliceSize);
      var byteNumbers = new Array(slice.length);
      for (var i = 0; i < slice.length; i++) {
        byteNumbers[i] = slice.charCodeAt(i);
      }
      var byteArray = new Uint8Array(byteNumbers);
      byteArrays.push(byteArray);
    }
    var blob = new Blob(byteArrays, {type: contentType});
    return blob;
  }

  //function creates the qr code using a blob format
  function qrCodeFormation(value, id) {
    var typeNumber = 8;
    var errorCorrectLevel = 'M';
    var qr_code = qrcode(typeNumber, errorCorrectLevel);
    qr_code.addData(value);
    qr_code.make();
    var base64Img = qr_code.createImgTag(typeNumber);
    var ImageURL = base64Img.split("\"")[1];
    var block = ImageURL.split(";");
    var contentType = block[0].split(":")[1];
    var realData = block[1].split(",")[1];
    var blob = b64toBlob(realData, contentType);
    var image = new Image();
    image.src = URL.createObjectURL(blob);
    $("#"+id).append(image);
  }

  qrCodeFormation(wlanconfstr, "qrcode");

  $("#btn-close").click(function() {
    sessionStorage.setItem("showAdvancedMode", false);
    var target = "modals/wireless-modal.lp"
    if (isNewLayout == "1") {
      target = "modals/wireless-ap-modal-newEM.lp"
    }
    tch.loadModal(target+'?radio=content_device&iface=getiface', '', function() {
      $(".modal").modal();
    });
  });

  radio_id = radio_id == "2" ? radio_id + ".4 GHz Wi-Fi" : radio_id + " GHz Wi-Fi";
  if ((isNewLayout == "1") && (split_ssid == "0" && currentType == "main" || (guest_split_ssid == "0" && currentType == "guest"))) {
    radio_id = "2.4GHz & 5GHz Wi-Fi";
  }

  $("#btn-to-print").click(function() {
    var win = window.open('');
    win.document.write('<p style="font-size:20px;">'+radio_id +'<br>'+ssid +'<br>Password : '+password+'<br> <img src="' + $("#qrcode").children('img')[0].src + '" onload="window.print();window.close()" />');
    win.focus();
  });
});
