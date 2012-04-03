jQuery(document).ready(function() {
  window.i = 0;
  $.history.init(pageload);
});

function pageload(hash) {
  if (hash) {
    window.hasHead = false;
    clearInterval(window.intervalID);
    window.hashjson = JSON.parse(base64Decode(hash));
    $('#query').html('<h3>' + window.hashjson.search + '</h3>');
    getStream();
    window.intervalID = setInterval("getStream()", 10000);
   }
   else {
    $('#tweets').html('<tr><td>No query</td></tr>');
   }
}

function getStream() {
  var from = new Date().getTime() - 10000;
  var time = {"from": ISODateString(from)};
  window.hashjson.timeframe = '20 seconds';
  var maxEvents = 15;
  var b64json = base64Encode(JSON.stringify(window.hashjson));
  $.getJSON(window.APP.path + "loader2.php?mode=stream&page=" + b64json, null, function(data) {
    if (data != null) {
      window.i++;
      var hasTime = false;
      var str = "";
      var i = 0;
      if(!window.hasHead) {
        str += "<thead>";
        str += "<th>Time</th>";
        for (var field in data.fields_requested) {
            str += "<th>" + data.fields_requested[field] + "</th>";
        }
        window.hasHead = true;
      }
      str += "</thead>";
      for (var obj in data.results) {
        if (!(hasTime)) {
          window.lastTime = (data.results[obj])['@timestamp'];
          hasTime = true;
        }
        if ($('#logrow_' + obj).length == 0) {
          str += "<tr id=logrow_" + obj + ">";
          i++;
          str += "<td style='white-space:nowrap;'>" +
            (data.results[obj])['@cabin_time'] + "</td>";
          for (var field in data.fields_requested) {
            str += "<td>" +
              (data.results[obj])[data.fields_requested[field]] + "</td>";
          }
          str += "</tr>";
        }

      }
      $(str).prependTo('#tweets');
      $('#meta').html(data.hits+' in '+window.hashjson.timeframe);
      $( 'tr:gt(' + ( maxEvents ) + ')' ).fadeOut(
        "normal", function() { $(this).remove(); } );
    }
  });
}

function ISODateString(unixtime) {
  d = new Date(parseInt(unixtime));

  function pad(n) {
    return n < 10 ? '0' + n : n
  }
  return d.getUTCFullYear() + '-' +
    pad(d.getUTCMonth() + 1) + '-' +
    pad(d.getUTCDate()) + 'T' +
    pad(d.getUTCHours()) + ':' +
    pad(d.getUTCMinutes()) + ':' +
    pad(d.getUTCSeconds())
}

