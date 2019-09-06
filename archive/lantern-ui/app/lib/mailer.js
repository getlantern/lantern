var mailer = function() {}

mailer.url = "https://mailer.getlantern.org";

mailer.send = function(data) {
  if (typeof data.to == 'undefined') {
    return false;
  }
  if (typeof data.template == 'undefined') {
    return false;
  };
  $.ajax({
    type: "POST",
    url: mailer.url + '/send',
    data: JSON.stringify(data),
    error: function(xhr, s, t) {
      console.log("error", t);
    }
  });
  return true;
};
