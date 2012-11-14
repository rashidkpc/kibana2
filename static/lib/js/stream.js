jQuery(document).ready(function() {
  window.i = 0;
  $.history.init(pageload);

  window.freq = 10;

  $("#pause_stream").click(function () {
    if (window.pause == true) {
      window.intervalID = setInterval("getStream()", (window.freq*1000));
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
  window.freq = 10;
  if (hash) {
    window.last_time = "";
    window.hasHead = false;
    clearInterval(window.intervalID);
    window.hashjson = JSON.parse(Base64.decode(hash));

    window.hashjson.fields = window.hashjson.fields.length > 0 ?
      window.hashjson.fields : new Array('@message');

    $('#query h4').text(window.hashjson.search);

    getStream();

    window.intervalID = setInterval("getStream()", (window.freq*1000));
   }
   else {
    $('#tweets').html('<tr><td>No query</td></tr>');
   }
}

function getStream() {
  var timeframe = window.freq;
  var maxEvents = 100;
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
      var id = "";
      var hit = "";
      var i = 0;
      data.hits.hits = data.hits.hits.reverse();
      for (var obj in data.hits.hits) {
        hit = data.hits.hits[obj]

        id = hit['_id']
        index = hit['_index']
        if (!(has_time)) {
          window.last_time = get_field_value(hit,'@timestamp');
          has_time = true;
        }
        if ($('#logrow_' + id).length == 0) {
          var tableRow = $("<tr/>").attr('id', "logrow_" + id);
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

          var jlink = $('<a/>').addClass('jlink').attr('href', "../#" + hash).html($('<i/>').addClass('icon-link'));
          var linkTableData = $("<td/>").css('white-space', 'nowrap');
          linkTableData.text(prettyDateString(Date.parse(get_field_value(hit,'@timestamp')) + tOffset)).prepend(jlink);
          tableRow.append(linkTableData);
          for (var field in fields) {
            tableRow.append($("<td/>").text(get_field_value(hit,fields[field])));
          }
          $("#tweets tbody").prepend(tableRow);
        }
      }
      $('#counter h3').fadeOut(100);
      console.log(data.hits.total)
      $('#counter h3').html(data.hits.total/timeframe+'/second');
      $('#counter h3').fadeIn(500);

      $( 'tr:gt(' + ( maxEvents ) + ')' ).fadeOut(
        "normal", function() { $(this).remove(); } );
      if(!window.hasHead) {
        window.hasHead = true;
        $('#tweets thead').append($("<th/>").text("Time"));
        for (var field in fields) {
          $('#tweets thead').append($("<th/>").text(fields[field]));
        }
      }
    }
  });
}
