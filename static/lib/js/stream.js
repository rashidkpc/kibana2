jQuery(document).ready(function() {
  window.i = 0;
  $.history.init(pageload);

  $("#pause_stream").click(function () {
    if (window.pause == true) {
      window.intervalID = setInterval("getStream()", 10000);
      window.pause = false;
      $('#pause_stream').text(' Pause');
      $('#pause_stream').removeClass('btn-info icon-play');

      $('#pause_stream').addClass('btn-warning icon-pause');
      getStream();
    } else {
      clearInterval(window.intervalID);
      window.pause = true;
      $('#pause_stream').text(' Play');
      $('#pause_stream').removeClass('btn-warning icon-pause');
      $('#pause_stream').addClass('btn-info icon-play');
    }
  });

});

function pageload(hash) {
  if (hash) {
    window.last_time = "";
    window.hasHead = false;
    clearInterval(window.intervalID);
    window.hashjson = JSON.parse(Base64.decode(hash));

    window.hashjson.fields = window.hashjson.fields.length > 0 ?
      window.hashjson.fields : new Array('@message');

    $('#query h4').html(window.hashjson.search);

    getStream();

    window.intervalID = setInterval("getStream()", 10000);
   }
   else {
    $('#tweets').html('<tr><td>No query</td></tr>');
   }
}

function getStream() {
  var timeframe = 10;
  var maxEvents = 15;
  var b64json = Base64.encode(JSON.stringify(window.hashjson));
  var from = ""

  if (window.last_time != "") {
    from = "/" + window.last_time;
  }

  $.getJSON("api/stream/" + b64json + from, null, function(data) {
    if (data != null) {
      window.i++;
      var fields = window.hashjson.fields
      var has_time = false;
      var header = "";
      var str = "";
      var id = "";
      var hit = "";
      var i = 0;
      for (var obj in data.hits.hits) {
        hit = data.hits.hits[obj]

        id = hit['_id']
        index = hit['_index']
        if (!(has_time)) {
          window.last_time = get_field_value(hit,'@timestamp');
          has_time = true;
        }
        if ($('#logrow_' + id).length == 0) {
          str += "<tr id=logrow_" + id + ">";
          i++;
          hash = Base64.encode(JSON.stringify(
            {
              "timeframe":"900",
              "mode":"id",
              "fields":"",
              "id":id,
              "index":index,
              "offset":0
            }
            ));
          str += "<td style='white-space:nowrap;'><a class=jlink href='../#"+hash+"'><i class='icon-link'></i></a> " +
            prettyDateString(Date.parse(get_field_value(hit,'@timestamp')) + tOffset) + "</td>";
          for (var field in fields) {
            str += "<td>" +
              get_field_value(hit,fields[field]) + "</td>";
          }
          str += "</tr>";
        }
      }

      $(str).prependTo('#tweets tbody');
      $('#counter h3').fadeOut(100)
      $('#counter h3').html(data.hits.total/timeframe+'/second');
      $('#counter h3').fadeIn(500)

      $( 'tr:gt(' + ( maxEvents ) + ')' ).fadeOut(
        "normal", function() { $(this).remove(); } );
      if(!window.hasHead) {
        header += "<th>Time</th>";
        for (var field in fields) {
            header += "<th>" + fields[field] + "</th>";
        }
        window.hasHead = true;
        $('#tweets thead').html(header)
      }
    }
  });
}
