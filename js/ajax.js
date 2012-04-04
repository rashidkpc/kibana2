$(document).ready(function () {

  var d = new Date()
  window.tOffset = -d.getTimezoneOffset() * 60 * 1000;

  $("#resetall").click(function () {
    window.location.hash = '#';
  });

  $('#timeinput').change(function () {
    window.hashjson.timeframe = $(this).val();
    if (window.hashjson.timeframe == "custom") {
      //Initialize the date picker with a 15 minute window into the past
      var d = new Date()
      var startDate = new Date(d - (15 * 60 * 1000));
      renderDateTimePicker(
        (startDate.getTime() + window.tOffset), (d.getTime() + window.tOffset));
    }
  });

  // Handle AJAX errors
  $("div#logs").ajaxError(function (e, xhr, settings, exception) {
    $('#meta').text("");
    showError("<strong>Oops!</strong> Something went terribly wrong.",
      "I'm not totally sure what happened, but maybe refreshing, or "+
      "hitting Reset will help. If that doesn't work, you can try "+
      "restarting your browser. If all else fails, it possible your"+
      " configuation has something funky going on. <br><br>If it helps,"+
      " I received a <strong>" + xhr.status + " " + xhr.statusText +
      "</strong> from: " + settings.url);
  });

  $('#sbctl').click(function () {
    var sb = $('#sidebar');
    if (sb.is(':visible')) {
      sbctl('hide');
    } else {
      sbctl('show');
    }
  });

  $("body").delegate(
    ".mfield", "click", function () {
      mFields($(this).text());
  });

  // Whenever the URL changes, fire this.
  $.history.init(pageload);

  // Resize flot graph with window
  $(window).smartresize(function () {
    if ($(".legend").length > 0){
      logGraph(window.graphdata,window.interval,window.hashjson.graphmode);
    }
  });
});

// This gets called every time the URL changes,
// Including hash changes, this setHash() will
// cause a reload of the results

function pageload(hash) {
  if (getcookie('username') != null)
    $('#dynamic_menu').html(
      '<a class="tab jlink" href="auth.php?logout">Logout</a>')
  //if hash value exists, run the ajax
  if (hash) {
    window.hashjson = JSON.parse(base64Decode(hash));

    // Take the hash data and populate the search fields
    $('#queryinput').val(window.hashjson.search);
    $('#fieldsinput').val(window.hashjson.fields);
    $('#timeinput').val(window.hashjson.timeframe);

    if(typeof window.hashjson.graphmode == 'undefined')
      window.hashjson.graphmode = 'count';

    if (window.hashjson.mode == 'analyze' ||
      window.hashjson.mode == 'trend'   ||
      window.hashjson.mode == 'mean')
    {
      getAnalysis();
    } else {
      $('#feedlinks').html(feedLinks(window.hashjson));
      getPage();
    }
  } else {
    resetAll();
  }
}

function getPage() {

  if (window.inprogress) {
    return false;
  }
  window.inprogress = true;

  // Show the user an animated loading thingy
  setMeta('','','loading');

  var sendhash = window.location.hash.replace(/^#/, '');;

  var data = 'page=' + sendhash;

  //Get the data and display it
  request = $.ajax({
    url: window.APP.path + "loader2.php",
    type: "GET",
    data: data,
    cache: false,
    success: function (json) {
      // Make sure we're still on the same page
      if (sendhash == window.location.hash.replace(/^#/, '')) {

        //Parse out the window hash
        window.resultjson = JSON.parse(json);

        //console.log(
        //  'curl -XGET \'http://elasticsearch:9200/'+resultjson.indices+
        //  '/_search?pretty=true\' -d\''+resultjson.elasticsearch_json+'\'');
        //console.log(window.resultjson.graph);

        $('#graphheader,#graph').text("");

        // Make sure we get some result before doing anything
        if (resultjson.hits > 0) {

          var fieldstr = "<p class=small>";
          for (var index in window.hashjson.fields) {
            fieldstr += "<a class='jlink mfield logfield_selected'>" +
              window.hashjson.fields[index] + "</a> ";
          }

          var analyzestr =
            '<ul id=analyze_list class="nav nav-pills nav-stacked">';
          var afield = '';
          window.resultjson.all_fields.sort();
          for (var index in resultjson.all_fields) {
            afield = resultjson.all_fields[index].toString().replace(
              '@', 'ATSYM') + "_field";

            analyzestr += '<li class="dropdown">' +
              '<a class="dropdown-toggle jlink" data-toggle="dropdown">' +
              resultjson.all_fields[index].toString() +
              '<b class=caret></b></a>' +
              '<ul class="dropdown-menu">' +
              "<li class='analyze_btn'>" +
              "<a class=jlink>Score</a></li> " +
              "<li class='trend_btn'>" +
              "<a class=jlink>Trend</a></li> "+
              "<li class='stat_btn'>" +
              "<a class=jlink>Statistics</a></li> "+
              "</ul>"+
              "</li>";

            if ($.inArray(
              resultjson.all_fields[index].toString(),
              window.hashjson.fields) < 0
            ) {
                fieldstr += "<a class='jlink mfield " + afield + "'>" +
                  resultjson.all_fields[index].toString() + "</a> ";
            }
          }

          $("#sidebar").delegate("li.analyze_btn a", "click", function () {
            analyzeField(
              $(this).parents().eq(2).children('a').text(), "analyze")});

          $("#sidebar").delegate("li.trend_btn a", "click",function () {
            analyzeField(
              $(this).parents().eq(2).children('a').text(), "trend")});

          $("#sidebar").delegate("li.stat_btn a", "click",function () {
            analyzeField(
              $(this).parents().eq(2).children('a').text(), "mean")});

          analyzestr += '</ul>';
          fieldstr += '</p>';
          $('#fields').html(
            "<h4><strong>Show</strong> Fields</h4>" + fieldstr);
          $('#analyze').html(
            "<h4><strong>Analyze</strong> Field</h4>" + analyzestr);

          $('.dropdown-toggle').dropdown();

          // Create and populate graph
          $('#graph').html(
            '<center><br><p><img src=' + window.APP.path + 'images/barload.gif></center>');
          getGraph(resultjson.graph.interval);

          // Create and populate #logs table
          $('#logs').html(CreateLogTable(
            window.resultjson.results, resultjson.fields_requested,
            'logs table-condensed'
          ));
          pageLinks();

        } else {
          showError('No logs matched',"Sorry, I couldn't find anything for that " +
            "query. Double check your spelling and syntax.");
        }

        // Populate meta data
        setMeta(window.resultjson.hits,window.resultjson.total,false);

        // display the body with fadeIn transition
        $('#logs').fadeIn('slow');
      }
    }
  });
  window.inprogress = false;
}

function getGraph(interval) {

  //generate the parameter for the php script
  var sendhash = window.location.hash.replace(/^#/, '');
  var mode = window.hashjson.graphmode;

  var data = 'page=' + sendhash + "&mode="+mode+"graph&interval=" + interval;

  //Get the data and display it
  request = $.ajax({
    url: window.APP.path + "loader2.php",
    type: "GET",
    data: data,
    cache: false,
    success: function (json) {

      // Make sure we're still on the same page
      if (sendhash == window.location.hash.replace(/^#/, '')) {

        //Parse out the returned JSON
        var graphjson = JSON.parse(json);

        window.graphdata = graphjson.graph.data
        window.interval = graphjson.graph.interval

        // Create and populate graph
        logGraph(
          graphjson.graph.data,
          window.interval,
          window.hashjson.graphmode
        );
      }
    }
  });
}

function analyzeField(field, mode) {
  window.hashjson.mode = mode;
  window.hashjson.analyze_field = field;
  setHash(window.hashjson);
}

function getAnalysis() {
  setMeta('','','loading');
  //generate the parameter for the php script
  var sendhash = window.location.hash.replace(/^#/, '');
  var data = 'page=' + sendhash + "&mode=" + window.hashjson.mode;
  //Get the data and display it
  request = $.ajax({
    url: window.APP.path + "loader2.php",
    type: "GET",
    data: data,
    cache: false,
    success: function (json) {
      // Make sure we're still on the same page
      if (sendhash == window.location.hash.replace(/^#/, '')) {

        //Parse out the returned JSON
        var field = window.hashjson.analyze_field;
        var resultjson = JSON.parse(json);
        window.resultjson = resultjson;

        if(window.resultjson.hits < 1) {
          if(window.resultjson.hits == 0) {
            setMeta(window.resultjson.hits,window.resultjson.total,false);
            showError('No logs matched '+
              '<button class="btn tiny btn-info" ' +
              'style="display: inline-block" id="back_to_logs">back to logs' +
              '</button>',
              "Sorry, I couldn't find anything for " +
              "that query. Double check your spelling and syntax.");
          }
          if(window.resultjson.hits == null) {
            setMeta(0,window.resultjson.total,false);
            showError('Statistical analysis unavailable for '+field +
              ' <button class="btn tiny btn-info" ' +
              'style="display: inline-block" id="back_to_logs">back to logs' +
              '</button>',
              "I'm not able to analyze <strong>" + field + "</strong>. " +
              "Statistical analysis is only available for fields " +
              "that are stored a number (eg float, int) in ElasticSearch");
          }

          $("#back_to_logs").click(function () {
            window.hashjson.mode = '';
            window.hashjson.graphmode = 'count';
            window.hashjson.analyze_field = '';
            setHash(window.hashjson);
          });
          return;
        }

        switch (window.hashjson.mode) {
        case 'analyze':
          if (resultjson.analysis.count == resultjson.hits) {
            var basedon = "<strong>all "
              + resultjson.analysis.count + "</strong>"
          } else {
            var basedon = 'the <strong>' +
              resultjson.analysis.count + ' most recent</strong>';
          }
          var title = '<h2>Quick analysis of ' +
            '<strong>' + window.hashjson.analyze_field + '</strong> field ' +
            '<button class="btn tiny btn-info" ' +
            'style="display: inline-block" id="back_to_logs">back to logs' +
            '</button>' +
            '</h2>' +
            'This analysis is based on ' + basedon +
            ' events for your query in your selected timeframe.<br><br>';
          $('#logs').html(
            title+CreateTableView(analysisTable(resultjson),'logs analysis'));
          graphLoading();
          window.hashjson.graphmode = 'count'
          getGraph(resultjson.graph.interval);
          break;
        case 'trend':
          var basedon = "<strong>" + resultjson.analysis.count + "</strong>";
          var title = '<h2>Trend analysis of <strong>' +
            window.hashjson.analyze_field + '</strong> field ' +
            '<button class="btn tiny btn-info" ' +
            'style="display: inline-block" id="back_to_logs">back to logs' +
            '</button>' +
            '</h2>' +
            'These trends are based on ' + basedon + ' events from beginning' +
            ' and end of the selected timeframe for your query.<br><br>';
          $('#logs').html(
            title+CreateTableView(analysisTable(resultjson),'logs analysis'));
          graphLoading();
          window.hashjson.graphmode = 'count'
          getGraph(resultjson.graph.interval);
          break;
        case 'mean':
          var title = '<h2>Stastical analysis of <strong>' +
            window.hashjson.analyze_field + '</strong> field ' +
            '<button class="btn tiny btn-info" ' +
            'style="display: inline-block" id="back_to_logs">back to logs' +
            '</button>' +
            '</h2>' +
            'Simple computations of a numeric field across your timeframe. ' +
            'The graph above <strong>shows the mean value</strong> ' +
            'of the <strong>'+field+
            '</strong> field over your selected time frame' +
            '<br><br>';
          var tbl = Array(), i = 0, metric;
          delete resultjson.analysis.results._type;
          for (var obj in resultjson.analysis.results) {
            metric = Array();
            metric['Statistic'] = obj.charAt(0).toUpperCase() + obj.slice(1);
            metric['Value'] = resultjson.analysis.results[obj];
            tbl[i] = metric;
            i++;
          }
          $('#logs').html(
            title+CreateTableView(tbl,'logs'));
          graphLoading();
          window.hashjson.graphmode = 'mean'
          getGraph(resultjson.graph.interval);
          break;
        }

        $("#logs").delegate("table.analysis tr td button", "click",
          function () {
            mSearch(
              field, $(this).parents().eq(1).children().eq(1).text()
            );
          }
        );

        $("#back_to_logs").click(function () {
          window.hashjson.mode = '';
          window.hashjson.graphmode = 'count';
          window.hashjson.analyze_field = '';
          setHash(window.hashjson);
        });

        $('.pagelinks').html('');
        $('#fields').html('');
        setMeta(resultjson.hits,resultjson.total,false);
      }
    }
  });
}

function graphLoading() {
  $('#graph').html(
    '<center><br><p><img src=' + window.APP.path + 'images/barload.gif></center>');
}

function analysisTable(resultjson) {
  var i = 0,
    metric = 0,
    isalt = '';
    tblArray = new Array();
  for (var obj in resultjson.analysis.results) {
    metric = resultjson.analysis.results[obj];
    metric['Rank'] = i+1;
    metric[window.hashjson.analyze_field] = obj;
    metric['Count'] = metric.count;
    metric['Percent'] =  Math.round(
      metric['count'] / resultjson.analysis.count * 10000
      ) / 100 + '%';
    if (window.hashjson.mode == 'trend') {
      if (metric['trend'] > 0) {
        metric['Trend'] = '<span class=positive>+' +
          metric['trend'] + '</span>';
      } else {
        metric['Trend'] = '<span class=negative>' +
          metric['trend'] + '</span>';
      }
      delete metric.trend;
      delete metric.start;
      delete metric.abs;
    }
    metric['Search'] = "<button style='display: inline-block' "+
      "class='btn tiny default'>Search</button></td>";
    delete metric.count;
    tblArray[i] = metric;
    i++;
  }
  return tblArray;
}

function setMeta(hits, indexed, mode) {
  var metastr = "";
  if ( mode == 'loading' ) {
    metastr += '<img src=' + window.APP.path + 'images/ajax-loader.gif>';
  } else {
    metastr = '<table class=formatting>' +
      "<tr><td>Hits</td><td>" + addCommas(hits) + "</td></tr>" +
      "<tr><td>Indexed</td><td>" + addCommas(indexed) + "</td></tr>" +
      "</table>";
  }
  $('#meta').html(metastr);
}

function pageLinks() {
  // Pagination
  var perpage = window.resultjson.meta.per_page
  var str = "<center>";
  if (window.hashjson.offset - perpage >= 0) {
    str += "<a class='firstpage jlink'>First</a> " +
      "<a class='prevpage jlink'>Prev</a> ";
  }
  var end = window.hashjson.offset + window.resultjson.page_count;
  str += "<strong>" + window.hashjson.offset + " TO " + end + "</strong> ";
  if (window.hashjson.offset + perpage < window.resultjson.hits) {
    str += "<a class='nextpage jlink'>Next</a> ";
  }
  str += "</center>";

  $('.pagelinks').html(str);

  $(".nextpage").click(function () {
    window.hashjson.offset = window.hashjson.offset + perpage;
    setHash(window.hashjson);
  });

  $(".prevpage").click(function () {
    window.hashjson.offset = window.hashjson.offset - perpage;
    setHash(window.hashjson);
  });

  $(".firstpage").click(function () {
    window.hashjson.offset = 0;
    setHash(window.hashjson);
  });
}

// This function creates a standard table with column/rows
// objArray = Anytype of object array, like JSON results
// theme (optional) = A css class to add to the table (e.g. <table class="<theme>">
// enableHeader (optional) = Controls if you want to hide/show, default is show
function CreateTableView(objArray, theme, enableHeader) {

  if (theme === undefined) theme = 'mediumTable'; //default theme
  if (enableHeader === undefined) enableHeader = true; //default enable header

  // If the returned data is an object do nothing, else try to parse
  var array = typeof objArray != 'object' ? JSON.parse(objArray) : objArray;

  var str = '<table class="' + theme + '">';

    // table head
  if (enableHeader) {
    str += '<thead><tr>';
    for (var index in array[0]) {
      str += '<th scope="col">' + index + '</th>';
    }
    str += '</tr></thead>';
  }

    // table body
  str += '<tbody>';
  for (var i = 0; i < array.length; i++) {
    str += (i % 2 == 0) ? '<tr class="alt">' : '<tr>';
    for (var index in array[i]) {
      str += '<td>' + array[i][index] + '</td>';
    }
    str += '</tr>';
  }
  str += '</tbody></table>';
  return str;
}


// This function creates a table of LOGS with column/rows
// objArray = Anytype of object array, like JSON results
// fields = Of the fields returned, only display these
// theme (optional) = A css class to add to the table (e.g. <table class="<theme>">
// enableHeader (optional) = Controls if you want to hide/show, default is show

function CreateLogTable(objArray, fields, theme, enableHeader) {
  // set optional theme parameter
  if (theme === undefined) {
    theme = 'mediumTable'; //default theme
  }

  if (enableHeader === undefined) {
    enableHeader = true; //default enable headers
  }

  if (objArray === undefined) {
    return "<br><center>" +
      "No results match your query. Please try a different search" +
      "</center><br>";
  }

  // If the returned data is an object do nothing, else try to parse
  var array = typeof objArray != 'object' ? JSON.parse(objArray) : objArray;

  // Remove empty items from fields array
  fields = $.grep(fields, function (n) {
    return (n);
  });

  // If no fields are specified, display @message
  if (fields.toString() === "") {
    fields[0] = '@message';
  }

  var str = '<table class="' + theme + '">';

  // table head
  if (enableHeader) {
    str += '<thead><tr>';
    str += '<th scope="col" class=firsttd>Time</th>';
    for (var index in fields) {
      str += '<th scope="col">' + fields[index] + '</th>';
    }
    str += '</tr></thead>';
  }

  // table body
  str += '<tbody>';
  var i = 1;
  for (var objid in array) {
    if (i % 2 == 0) {
      str += '<tr class="alt logrow" onclick=\'viewLog("' + objid + '")\'>';
    } else {
      str += '<tr class="logrow" onclick=\'viewLog("' + objid + '")\'>';
    }
    str += '<td class=firsttd>' + array[objid]['@cabin_time'] + '</td>';
    for (var index in fields) {
      if(array[objid][fields[index]] === undefined) {
        tdvalue = "-"
      } else {
        tdvalue = array[objid][fields[index]].toString();
      }
      str += '<td>' + xmlEnt(wbr(tdvalue, 10)) + '</td>';
    }
    str += '</tr><tr id=logrow_' + objid + ' class=hidedetails><td id=log_' +
      objid + ' colspan=100></td></tr>';
    i++;
  }

  str += '</tbody></table>';
  return str;
}

function viewLog(objid) {
  obj = sortObj(window.resultjson.results[objid]);

  // Create a table of information about the log
  var str = "<table class='logdetails table-bordered'>" +
    "<tr><th>Field</th><th>Value</th></tr>";
  var i = 1;
  var selected = ""
  for (field in obj) {
    var field_id = field.replace('@', 'ATSYM');
    selected = "";
    if ($.inArray(field, window.hashjson.fields) > -1) {
      selected = "logfield_selected";
    }
    value = obj[field].toString();
    if (!(field.match(/^@cabin_/))) {
      trclass = (i % 2 == 0) ? 'class=alt' : '';
      str += "<tr " + trclass + ">" +
        "<td class='firsttd " + field_id + "_field "
        + selected + "'>" + field +
        "</td>" +
        '<td>' + xmlEnt(wbr(value, 10)) + "<span style='display:none'>" +
        xmlEnt(value) + "</span>" +
        " <div style='display: inline-block'>" +
        "<button style='display: inline-block' class='btn tiny' id=findthis_"+
        objid+"_"+field_id+">Find this</button> " +
        "<button style='display: inline-block' class='btn tiny' id=notthis_"+
        objid+"_"+field_id+">NOT this</button> " +
        "</div>" +
        "</td></tr>";
      i++;
    }

    $("body").delegate(
      "#findthis_"+objid+"_"+field_id, "click", function (objid) {
        mSearch(
          $(this).parents().eq(2).find('.firsttd').text(),
          $(this).parents().eq(1).find('span').text()
        );
    });

    $("body").delegate(
      "#notthis_"+objid+"_"+field_id, "click", function (objid) {
        mSearch(
          "NOT " + $(this).parents().eq(2).find('.firsttd').text(),
          $(this).parents().eq(1).find('span').text()
        );
    });

  }
  str += "</table>";

  // Populate td with that table
  $('#log_' + objid).html(str);



  $('.ui-state-default').hover(function () {
    $(this).toggleClass('ui-state-hover');
  });
  $('.ui-state-default').click(function () {
    $(this).toggleClass('ui-state-active');
  });

  // Regular jQuery toggle() doesn't work with table-rows
  $('#logrow_' + objid).toggleClass('showdetails');
  $('#logrow_' + objid).toggleClass('hidedetails');


}

function getLogField(objid, field) {
  obj = window.resultjson.results[objid];
  return obj[field];
}

function mSearch(field, value) {
  window.hashjson.mode = '';
  window.hashjson.analyze_field = '';
  var glue = $('#queryinput').val() != "" ? " AND " : " ";
  window.hashjson.search = $('#queryinput').val() + glue + field + ":" + "\"" +
    addslashes(value.toString()) + "\"";
  setHash(window.hashjson);
  scroll(0, 0);
}

function mFields(field) {
  if ($.inArray(field, window.hashjson.fields) < 0) {
    window.hashjson.fields.push(field);
  } else {
    window.hashjson.fields = jQuery.grep(
      window.hashjson.fields, function (value) {
        return value != field;
      }
    );
  }

  window.hashjson.fields = $.grep(window.hashjson.fields,function(n){
    return(n);
  });

  $('#fieldsinput').val(window.hashjson.fields);
  var str = "";
  for (var index in window.hashjson.fields) {
    str += "<a class='jlink mfield logfield_selected'>"
      + window.hashjson.fields[index] + "</a> ";
  }
  
  for (var index in window.resultjson.all_fields) {
    if ($.inArray(resultjson.all_fields[index].toString(),
      window.hashjson.fields) < 0) {
      str += "<a class='jlink mfield " +
        resultjson.all_fields[index].toString().replace('@', 'ATSYM') +
        "_field '>" +
        resultjson.all_fields[index].toString() + "</a> ";
    }
  }
  $('#fields').html("<h4><strong>Show</strong> Fields</h4> " + str);
  $('td.' + field.replace('@', 'ATSYM') + '_field').toggleClass(
    'logfield_selected');

  $('#logs').html(CreateLogTable(
    window.resultjson.results, window.hashjson.fields, 'logs table-condensed'));

  $('#feedlinks').html(feedLinks(window.hashjson));

  pageLinks();

}

function feedLinks(obj) {
  var str = "<a href=" + window.APP.path + "loader2.php?mode=rss&page=" +
    base64Encode(JSON.stringify(obj)) +
    ">rss <img src=" + window.APP.path + "images/feed.png></a> "+
    "<a href=" + window.APP.path + "loader2.php?mode=csv&page=" +
    base64Encode(JSON.stringify(obj)) +
    ">export <img src=" + window.APP.path + "images/csv.gif></a> "+
    "<a href=" + window.APP.path + "stream.html#" +
    base64Encode(JSON.stringify(obj)) +
    ">stream <img src=" + window.APP.path + "images/stream.png></a>"
  return str;
}

// Split up log spaceless strings
// Str = string to split
// num = number of letters between <wbr> tags

function wbr(str, num) {
  return str.replace(RegExp("(\\w{" + num + "}|[:;,])([\\w\"'])", "g"),
    function (all, text, char) {
      return text + "<del>&#8203;</del>" + char;
    }
  );
}

$(function () {
  $('form').submit(function () {
    if (window.hashjson.search != $('#queryinput').val()) {
      //delete window.hashjson.time;
      window.hashjson.offset = 0;
      window.hashjson.search = $('#queryinput').val();
    }
    window.hashjson.stamp = new Date().getTime();
    window.hashjson.fields = $('#fieldsinput').val().split(',');

    if (window.hashjson.timeframe == "custom") {
      $('#timechange').click();
    }
    else {
      window.hashjson.timeframe = $('#timeinput').val();
    }


    if (window.location.hash == "#" + JSON.stringify(window.hashjson)) {
      pageload(window.location.hash);
    } else {
      setHash(window.hashjson);
    }
    return false;
  });
});


// Sets #hash, thus refreshing results
function setHash(json) {
  window.location.hash = base64Encode(JSON.stringify(json));
}


// Add commas to numbers
function addCommas(nStr) {
  nStr += '';
  x = nStr.split('.');
  x1 = x[0];
  x2 = x.length > 1 ? '.' + x[1] : '';
  var rgx = /(\d+)(\d{3})/;
  while (rgx.test(x1)) {
    x1 = x1.replace(rgx, '$1' + ',' + '$2');
  }
  return x1 + x2;
}

// Render the date/time picker
function renderDateTimePicker(from, to) {
  if (!$('#timechange').length) {
    var maxDateTime = new Date();
    // set to midnight of current day
    maxDateTime.setHours(23,59,59,999);
    $('#graphheader').html("<table width='100%'><tr><td width='20%'></td><td width='60%' align='center'>" +
      "<input size=19 id=timefrom class=hasDatePicker " +
      "type=text name=timefrom value='" + ISODateString(from) + "'> to " +
      "<input size=19 id=timeto class=hasDatePicker " +
      " type=text name=timeto value='" + ISODateString(to) + "'> " +
      "<button id='timechange' style='visibility: hidden' " +
      "class='btn tiny success'>Filter</button></td>" +
      "<td width='20%' align='right'>Graph Granularity <select name='barspan' id=barspan style='width: 100px'><option value='100'>Low</option><option value='10'>Medium</option><option value='1'>High</option></select></td></tr></table>"
    );

    $('#timefrom').datetimepicker({
      showSecond: true,
      timeFormat: 'hh:mm:ss',
      dateFormat: 'yy-mm-dd',
      separator: 'T',
      maxDate: maxDateTime,
      maxDateTime: maxDateTime,
      onSelect: function (dateText, inst) {
        // Work arround bug: /jQuery-Timepicker-Addon/issues/302
        if ($('#timeto').val() != '') {
          $('#timeto').datetimepicker('setDate',
            $('#timeto').val());
        }
        var tFrom = $(this).datetimepicker('getDate').getTime();
        var tTo = $('#timeto').datetimepicker('getDate').getTime();
        var now = new Date().getTime();
        if (tFrom > now-(1000*60)) {
          // set timeto to now and timefrom to now - 1 min
          $('#timeto').datetimepicker('setDate', (new Date(now)));
          $('#timefrom').datetimepicker('setDate',
            (new Date(now-60*1000)));
        } else if (tFrom > tTo-(1000*60)) {
          // set timeto to min(now, timefrom + 15 min)
          $('#timeto').datetimepicker('setDate',
            (new Date(Math.min(now, tFrom+(15*60*1000)))));
        }
        $('#timechange').css('visibility', 'visible');
        $('#timeinput').val('custom');
      }
    });

    $('#timeto').datetimepicker({
      showSecond: true,
      timeFormat: 'hh:mm:ss',
      dateFormat: 'yy-mm-dd',
      separator: 'T',
      maxDate: maxDateTime,
      maxDateTime: maxDateTime,
      onSelect: function (dateText, inst) {
        if ($('#timefrom').val() != '') {
          $('#timefrom').datetimepicker('setDate',
            $('#timefrom').val());
        }
        var tTo = $(this).datetimepicker('getDate').getTime();
        var tFrom = $('#timefrom').datetimepicker('getDate').getTime();
        var now = new Date().getTime();
        if (tTo > now) {
          // set timeto to now
          $('#timeto').datetimepicker('setDate', (new Date(now)));
        } else if (tFrom > tTo) {
          // set timefrom to timeto - 15 min
          $('#timefrom').datetimepicker('setDate',
            (new Date(tTo-15*60*1000)));
        }
        $('#timechange').css('visibility', 'visible');
        $('#timeinput').val('custom');
      }
    });

    $('#timefrom,#timeto').change(function () {
      $('#timechange').css('visibility', 'visible');
      $('#timeinput').val('custom');
      $('#timeinput').change();
    });

    // Give user a nice interface for selecting time ranges
    $("#timechange").click(function () {
      var time = {
        "from": ISODateString(Date.parse($('#timefrom').val())-window.tOffset),
        "to": ISODateString(Date.parse($('#timeto').val())-window.tOffset)
      };
      window.hashjson.offset = 0;
      window.hashjson.time = time;
      window.hashjson.timeframe = "custom";
      setHash(window.hashjson);
    });
    
    $('#barspan').change(function () {
      window.hashjson.barspan = $(this).val();
	    setHash(window.hashjson);
	  });
  }
}


// Big horrible function for creating graphs
function logGraph(data, interval, metric) {

  // If mode is graph, graph count, otherwise remove word 'graph' and chart
  // whatever is left. ie meangraph -> mean
  if (typeof metric === 'undefined')
    metric = 'count';

  metric = metric.replace('graph','');
  if (metric === '')
    metric = 'count';

  var array = new Array();
  if(typeof window.resultjson.time !== 'undefined') {
    // add null value at time from.
    array.push(Array(Date.parse(window.resultjson.time.from) + window.tOffset, null));
  }
  for (var index in data) {
    value = data[index][metric];
    array.push(Array(data[index].time + window.tOffset, value));
  }
  if(typeof window.resultjson.time !== 'undefined') {
    // add null value at time to.
    array.push(Array(Date.parse(window.resultjson.time.to) + window.tOffset, null));
    renderDateTimePicker(Date.parse(window.resultjson.time.from) + window.tOffset, 
    Date.parse(window.resultjson.time.to) + window.tOffset);
  } else {
    var from = data[0].time + window.tOffset;
    var to = data[data.length - 1].time + window.tOffset;
    renderDateTimePicker(from, to);
  }


  // Make sure we get results before calculating graph stuff
  if (!jQuery.isEmptyObject(data)) {
    var from = window.resultjson.time.from + window.tOffset;
    var to = window.resultjson.time.to + window.tOffset;
    renderDateTimePicker(from, to);

    // Allow user to select ranges on graph.
    // Its this OR click, not both it seems.
    var intset = false;
    $('#graph').bind("plotselected", function (event, ranges) {
      if (!intset) {
        intset = true;
        var time = {
          "from": ISODateString(
            parseInt(ranges.xaxis.from.toFixed(0)) - window.tOffset),
          "to": ISODateString(
            parseInt(ranges.xaxis.to.toFixed(0)) - window.tOffset)
        };
        window.hashjson.offset = 0;
        window.hashjson.time = time;
        window.hashjson.timeframe = "custom";
        setHash(window.hashjson);
      }
    });


    // Allow user to hover over a bar and get details
    var previousPoint = null;
    $("#graph").bind("plothover", function (event, pos, item) {
      $("#x").text(pos.x.toFixed(2));
      $("#y").text(pos.y.toFixed(2));

      if (item) {
        if (previousPoint != item.dataIndex) {
          previousPoint = item.dataIndex;

          $("#tooltip").remove();
          var x = item.datapoint[0].toFixed(0),
            y = Math.round(item.datapoint[1]*100)/100;

          showTooltip(
            item.pageX, item.pageY, y + " at " + ISODateString(x)
          );
        }
      } else {
        $("#tooltip").remove();
        previousPoint = null;
      }
    });

    var label = 'Logs';
    if (metric !== '')
      label = metric;

    var color = getGraphColor(metric);

    $.plot(
    $("#graph"), [{
      data: array,
      label: label + " per " + (parseInt(interval) / 1000) + "s"
    }], {
      series: {
        lines: {
          show: false,
          fill: true
        },
        bars: {
          show: true,
          fill: 1,
          barWidth: interval / 1.7
        },
        points: {
          show: false
        },
        color: color,
        shadowSize: 0
      },
      xaxis: {
        mode: "time",
        timeformat: "%H:%M:%S<br>%m/%d",
        label: "Datetime",
        color: "#000"
      },
      yaxis: {
        min: 0,
        color: "#000"
      },
      selection: {
        mode: "x",
        color: '#000'
      },
      grid: {
        backgroundColor: '#fff',
        borderWidth: 0,
        borderColor: '#000',
        color: "#ddd",
        hoverable: true,
        clickable: true
      }
    });
  }

}

function showTooltip(x, y, contents) {
  $('<div id="tooltip">' + contents + '</div>').css({
    position: 'absolute',
    display: 'none',
    top: y - 20,
    left: x - 200,
    color: '#eee',
    border: '1px solid #fff',
    padding: '3px',
    'font-size': '8pt',
    'background-color': '#000',
    border: '1px solid #000',
    'font-family': '"Verdana", Geneva, sans-serif'
  }).appendTo("body").fadeIn(200);
}

// Create an ISO8601 compliant timestamp for ES
function ISODateString(unixtime) {
  var d = new Date(parseInt(unixtime));

  function pad(n) {
    return n < 10 ? '0' + n : n
  }
  return d.getUTCFullYear() + '-' +
    pad(d.getUTCMonth() + 1) + '-' +
    pad(d.getUTCDate()) + 'T' +
    pad(d.getUTCHours()) + ':' +
    pad(d.getUTCMinutes()) + ':' +
    pad(d.getUTCSeconds());
}

function is_int(value) {
  if ((parseFloat(value) == parseInt(value)) && !isNaN(value)) {
    return true;
  } else {
    return false;
  }
}

function xmlEnt(value) {
  var stg1 = value.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(
    /\n/g, '<br/>').replace(/\t/g, '&nbsp;&nbsp;&nbsp;&nbsp;');
  return stg1.replace(/&lt;del&gt;/g, '<del>').replace(
    /&lt;\/del&gt;/g, '</del>');
}

function sortObj(arr) {
  // Setup Arrays
  var sortedKeys = new Array();
  var sortedObj = {};

  // Separate keys and sort them
  for (var i in arr) {
    sortedKeys.push(i);
  }
  sortedKeys.sort();

  // Reconstruct sorted obj based on keys
  for (var i in sortedKeys) {
    sortedObj[sortedKeys[i]] = arr[sortedKeys[i]];
  }
  return sortedObj;
}

function sbctl(mode) {
  var sb = $('#sidebar'),
    main = $('#main'),
    lnk = $('#sbctl'),
    win = $(window);
  if (mode == 'hide') {
    // collapse
    sb.hide();
    main.removeClass('span10');
    main.addClass('span12');
    lnk.removeClass('ui-icon-triangle-1-w');
    lnk.addClass('ui-icon-triangle-1-e');
    main.addClass('sidebar-collapsed');
    win.smartresize();
  }
  if (mode == 'show') {
    sb.show();
    main.removeClass('span12');
    main.addClass('span10');
    lnk.removeClass('ui-icon-triangle-1-e');
    lnk.addClass('ui-icon-triangle-1-w');
    main.removeClass('sidebar-collapsed');
    win.smartresize();
  }
}

function addslashes(str) {
  str = str.replace(/\\/g, '\\\\');
  str = str.replace(/\'/g, '\\\'');
  str = str.replace(/\"/g, '\\"');
  str = str.replace(/\0/g, '\\0');
  return str;
}

function getcookie(name) {
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for (var i = 0; i < ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') c = c.substring(1, c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
  }
  return null;
}

function showError(title,text) {
  // blank out Fields
  $('#fields').html("<h4><strong>Show</strong> Fields</h4>");
  // blank out Analyze Field
  $('#analyze').html("<h4><strong>Analyze</strong> Field</h4>");
  pageLinks();
  // blank out pagelinks
  $('.pagelinks').html("");
  // blank out logs
  $('#logs').html("");
  // Nothing found error message
  $('#graph').html("<h2>"+title+"</h2>"+text);

  // We have to use hashjson's time here since we won't
  // get a resultjson on error, usually
  if(typeof window.hashjson.time !== 'undefined') {
    renderDateTimePicker(
      Date.parse(window.hashjson.time.from) + window.tOffset,
      Date.parse(window.hashjson.time.to) + window.tOffset
    );
  }
}

function getGraphColor(mode) {
  switch(mode)
  {
  case "mean":
    var color = '#ef9a23';
  break;
  default:
    var color = '#5aba65';
  }
  return color;
}

function resetAll() {
  window.hashjson = JSON.parse(
    '{'+
      '"search":"",'+
      '"fields":[],'+
      '"offset":0,'+
      '"timeframe":"15 minutes",'+
      '"graphmode":"count"'+
    '}'
  );
  setHash(window.hashjson);
}
