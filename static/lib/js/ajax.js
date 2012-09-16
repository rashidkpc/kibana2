$(document).ready(function () {

  // Bind all click/change/whatever handlers
  bind_clicks()

  // Handle AJAX errors
  $("div#logs").ajaxError(function (e, xhr, settings, exception) {
    $('#meta').text("");
    if(xhr.statusText != 'abort') {
      showError("<strong>Oops!</strong> Something went terribly wrong.",
        "I'm not totally sure what happened, but maybe refreshing, or "+
        "hitting Reset will help. If that doesn't work, you can try "+
        "restarting your browser. If all else fails, it is possible your"+
        " configuation has something funky going on. <br><br>If it helps,"+
        " I received a <strong>" + xhr.status + " " + xhr.statusText +
        "</strong> from: " + settings.url);
      //console.log(xhr);
    }
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
// Including hash changes, setHash() will
// cause a reload of the results

function pageload(hash) {
  if (typeof window.request !== 'undefined') {
    window.request.abort();
    delete window.segment;
  }
  //if hash value exists, run the ajax
  if (hash) {
    window.hashjson = JSON.parse(Base64.decode(hash));

    //console.log(window.hashjson)

    // Take the hash data and populate the search fields
    $('#queryinput').val(window.hashjson.search);
    $('#timeinput').val(window.hashjson.timeframe);

    if(typeof window.hashjson.graphmode == 'undefined')
      window.hashjson.graphmode = 'count';

    switch (window.hashjson.mode) {
    case 'score':
    case 'trend':
    case 'mean':
      getAnalysis();
      break;
    case 'id':
      getID();
      break;
    default:
      $('#feedlinks').html(feedLinks(window.hashjson));
      getPage();
      break;
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
  setMeta('loading');

  var sendhash = window.location.hash.replace(/^#/, '');;

  //Get the data and display it
  window.request = $.ajax({
    url: "api/search/"+sendhash,
    type: "GET",
    cache: false,
    success: function (json) {
      // Make sure we're still on the same page
      if (sendhash == window.location.hash.replace(/^#/, '')) {
        //Parse out the result
        window.resultjson = JSON.parse(json);

        if (typeof window.resultjson.kibana.error !== 'undefined') {
          setMeta(0);
          showError('No logs matched',"Sorry, I couldn't find anything for " +
            "that query. Double check your spelling and syntax.");
          return;
        }

        //console.log(
        //  'curl -XGET \'http://elasticsearch:9200/'+resultjson.index+
        //  '/_search?pretty=true\' -d\''+resultjson.elasticsearch_json+'\'');
        //console.log(resultjson);

        $('#graphheader,#graph').text("");

        // Make sure we get some results before doing anything
        if (resultjson.hits.total > 0) {

          // Setup variables
          window.all_fields = get_all_fields(resultjson);
          var fieldstr = "";
          var analyzestr =
            '<ul id=analyze_list class="nav nav-pills nav-stacked">';
          var afield = ''; // Adjusted field name, removing @
          var selected_class = "logfield_selected"

          // Determine fields to be displayed
          if (window.hashjson.fields.length == 0) {
            fields = resultjson.kibana.default_fields;
            selected_class = '';
          } else {
            fields = window.hashjson.fields
          }
          //console.log(window.default_fields)

          for (var index in fields) {
            afield = window.all_fields[index].toString().replace(
              '@', 'ATSYM') + "_field";
            fieldstr += "<a class='jlink mfield "+selected_class+" "+afield+"'>" +
              fields[index] + "</a> ";
          }

          for (var index in window.all_fields) {
            afield = window.all_fields[index].toString().replace(
              '@', 'ATSYM') + "_field";

            analyzestr += '<li class="dropdown">' +
              '<a class="dropdown-toggle jlink" data-toggle="dropdown">' +
              window.all_fields[index].toString() +
              '<b class=caret></b></a>' +
              '<ul class="dropdown-menu">' +
              "<li class='analyze_btn'>" +
              "<a class=jlink><i class='icon-list-ol'></i> Score</a></li> " +
              "<li class='trend_btn'>" +
              "<a class=jlink><i class='icon-tasks'></i> Trend</a></li> "+
              "<li class='stat_btn'>" +
              "<a class=jlink><i class='icon-bar-chart'></i> Statistics</a></li> "+
              "</ul>"+
              "</li>";

            if ($.inArray(window.all_fields[index].toString(), fields) < 0 ) {
                fieldstr += "<a class='jlink mfield " + afield + "'>" +
                  window.all_fields[index].toString() + "</a> ";
            }
          }

          analyzestr += '</ul>';
          $('#fields').html(
            "<h5><i class='icon-columns'></i> Columns</h5>" + fieldstr);
          $('#analyze').html(
            "<h5><i class='icon-cog'></i> Analysis</h5>" + analyzestr);

          // Button delegations
          $("#sidebar").delegate("li.analyze_btn a", "click", function () {
            window.hashjson.offset = 0;
            analyzeField(
              $(this).parents().eq(2).children('a').text(), "score")});

          $("#sidebar").delegate("li.trend_btn a", "click",function () {
            window.hashjson.offset = 0;
            analyzeField(
              $(this).parents().eq(2).children('a').text(), "trend")});

          $("#sidebar").delegate("li.stat_btn a", "click",function () {
            window.hashjson.offset = 0;
            analyzeField(
              $(this).parents().eq(2).children('a').text(), "mean")});


          $('.dropdown-toggle').dropdown();

          // Create and populate #logs table
          $('#logs').html(CreateLogTable(
            window.resultjson.hits.hits, fields,
            'table logs table-condensed'
          ));
          pageLinks();

          // Populate hit and total
          setMeta(window.resultjson.hits.total);

          // Create and populate graph
          $('#graph').html(
            '<center><br><p><img src=' +
            '/images/barload.gif></center>');

          //console.log(window.hashjson)
          window.interval = calculate_interval(
            Date.parse(window.resultjson.kibana.time.from),
            Date.parse(window.resultjson.kibana.time.to),
            100
          )
          getGraph(window.interval);

        } else {

          // Populate hits and total
          setMeta(window.resultjson.hits.total);

          showError('No logs matched',"Sorry, I couldn't find anything for " +
            "that query. Double check your spelling and syntax.");
        }
        $('#feedlinks').html(feedLinks(window.hashjson));
      }
    }
  });
  window.inprogress = false;
}

function getGraph(interval) {

  //generate the parameter for the php script
  var sendhash = window.location.hash.replace(/^#/, '');
  var mode = window.hashjson.graphmode;
  window.segment = typeof window.segment === 'undefined' ? '' : window.segment;
  //Get the data and display it
  window.request = $.ajax({
    url: "api/graph/"+mode+"/"+interval+"/"+sendhash+"/"+window.segment,
    type: "GET",
    cache: false,
    success: function (json) {
      // Make sure we're still on the same page
      if (sendhash == window.location.hash.replace(/^#/, '')) {

        //Parse out the returned JSON
        var graphjson = JSON.parse(json);
        //console.log(graphjson)
        if ($(".legend").length > 0) {
          window.graphdata = graphjson.facets[mode].entries.concat(window.graphdata);
          window.graphhits = graphjson.hits.total + window.graphhits
        } else {
          window.graphdata = graphjson.facets[mode].entries
          window.graphhits = graphjson.hits.total
        }

        setMeta(window.graphhits);

        // Display graph data
        logGraph(
          window.graphdata,
          interval,
          mode);

        if (typeof graphjson.kibana.next !== 'undefined') {
          window.segment = graphjson.kibana.next;
          if (!($(".graphloading").length > 0)) {
            $('div.legend table, div.legend table td').css({
              "background-image": "url("
                + "/images/barload.gif)",
              "background-size":  "100% 100%"
            });
          }
          getGraph(interval);
        } else {
          if(typeof window.segment !== 'undefined')
            delete window.segment
        }

      }
    }
  });
}

function analyzeField(field, mode) {
  window.hashjson.mode = mode;
  window.hashjson.analyze_field = field;
  setHash(window.hashjson);
}

function getID() {
  // Show the user an animated loading thingy
  var sendhash = window.location.hash.replace(/^#/, '');
  //Get the data and display it
  window.request = $.ajax({
    url: "api/id/"+window.hashjson.id+"/"+window.hashjson.index,
    type: "GET",
    cache: false,
    success: function (json) {
      window.resultjson = JSON.parse(json)
      hit = resultjson.hits.hits[0]
      blank_page();
      setMeta(1);

      str = details_table(0, 'table table-bordered');
      $('#graph').html("<h2>Details for log ID: "+hit._id+" in "+hit._index+"</h2><br>"+str);
    }
  });
  delete window.hashjson.id
  delete window.hashjson.index
  delete window.hashjson.mode
}

function getAnalysis() {
  setMeta('loading');
  //generate the parameter for the php script
  var sendhash = window.location.hash.replace(/^#/, '');
  //Get the data and display it
  window.request = $.ajax({
    url: "api/analyze/"+window.hashjson.analyze_field+"/"+window.hashjson.mode+"/"+sendhash,
    type: "GET",
    cache: false,
    success: function (json) {
      // Make sure we're still on the same page
      if (sendhash == window.location.hash.replace(/^#/, '')) {

        //Parse out the returned JSON
        var field = window.hashjson.analyze_field;
        var resultjson = JSON.parse(json);
        window.resultjson = resultjson;

        //console.log(resultjson);

        $('.pagelinks').html('');
        $('#fields').html('');

        if(typeof resultjson.error !== 'undefined') {
          setMeta(0);
          showError('Statistical analysis unavailable for '+field +
            ' <button class="btn tiny btn-info" ' +
            'style="display: inline-block" id="back_to_logs">back to logs' +
            '</button>',
            "I'm not able to analyze <strong>" + field + "</strong>. " +
            "Statistical analysis is only available for fields " +
            "that are stored a number (eg float, int) in ElasticSearch");
          return;
        }

        window.interval = calculate_interval(
          Date.parse(window.resultjson.kibana.time.from),
          Date.parse(window.resultjson.kibana.time.to),
          100
        )

        if(resultjson.hits.total == 0) {
          setMeta(resultjson.hits.total);
          showError('No logs matched '+
            '<button class="btn tiny btn-info" ' +
            'style="display: inline-block" id="back_to_logs">back to logs' +
            '</button>',
            "Sorry, I couldn't find anything for " +
            "that query. Double check your spelling and syntax.");
          return;
        }

        setMeta(resultjson.hits.total);
        switch (window.hashjson.mode) {
        case 'score':
          if (resultjson.hits.count == resultjson.hits.total) {
            var basedon = "<strong>all "
              + resultjson.hits.count + "</strong>"
          } else {
            var basedon = 'the <strong>' +
              resultjson.hits.count + ' most recent</strong>';
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
          getGraph(window.interval);
          break;
        case 'trend':
          var basedon = "<strong>" + resultjson.hits.count + "</strong>";
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
          getGraph(window.interval);
          break;
        case 'mean':
          var title = '<h2>Statistical analysis of <strong>' +
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
          delete resultjson.facets.stats._type;
          for (var obj in resultjson.facets.stats) {
            metric = Array();
            metric['Statistic'] = obj.charAt(0).toUpperCase() + obj.slice(1);
            metric['Value'] = resultjson.facets.stats[obj];
            tbl[i] = metric;
            i++;
          }
          $('#logs').html(
            title+CreateTableView(tbl,'logs'));
          graphLoading();
          window.hashjson.graphmode = 'mean'
          getGraph(window.interval);
          break;
        }
      }
    }
  });
}

function graphLoading() {
  $('#graph').html(
    '<center><br><p><img src=' +
    '/images/barload.gif></center>');
}

function analysisTable(resultjson) {
  var i = 0,
    metric = {},
    isalt = '',
    tblArray = new Array();
  for (var obj in resultjson.hits.hits) {
    metric = {},
    object = resultjson.hits.hits[obj];
    metric['Rank'] = i+1;
    metric[window.hashjson.analyze_field] = object.id;
    metric['Count'] = object.count;
    metric['Percent'] =  Math.round(
      metric['Count'] / resultjson.hits.count * 10000
      ) / 100 + '%';
    if (window.hashjson.mode == 'trend') {
      if (object.trend > 0) {
        metric['Trend'] = '<span class=positive>+' +
          object.trend + '</span>';
      } else {
        metric['Trend'] = '<span class=negative>' +
          object.trend + '</span>';
      }
    }
    metric['Action'] =  "<i class='search icon-search icon-large jlink'></i> " +
                        "<i class='rescore icon-cog icon-large jlink'></i>";

    tblArray[i] = metric;
    i++;
  }
  return tblArray;
}

function setMeta(hits, mode) {
  if ( hits == 'loading' ) {
    $('#meta').html('<img src=/images/ajax-loader.gif>');
  } else {
    $('#meta').html(addCommas(hits) + " <span class=small>hits</span></td></tr>");
  }
}

function pageLinks() {
  // Pagination
  var perpage = window.resultjson.kibana.per_page
  var str = "<center>";
  if (window.hashjson.offset - perpage >= 0) {
    str += "<i class='firstpage jlink icon-circle-arrow-left'></i> " +
      "<i class='prevpage icon-arrow-left jlink'></i> ";
  }
  var end = window.hashjson.offset + window.resultjson.hits.hits.length;
  str += "<strong>" + window.hashjson.offset + " TO " + end + "</strong> ";
  if (end < resultjson.hits.total)
  {
    str += "<i class='nextpage icon-arrow-right jlink'></i> ";
  }
  str += "</center>";

  $('.pagelinks').html(str);
}

// This is very ugly
function blank_page() {
  $('#graph').text("");
  $('#graphheader').text("");
  $('#feedlinks').text("");
  $('#logs').text("");
  $('.pagelinks').text("");
  $('#fields').text("");
  $('#analyze').text("");
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
  theme = theme === undefined ? 'mediumTable' : theme;
  enableHeader = enableHeader === undefined ? true : false;

  if (objArray === undefined) {
    return "<center>" +
      "No results match your query. Please try a different search" +
      "</center><br>";
  }

  if (fields.length == 0)
    fields = window.resultjson.kibana.default_fields;

  // If the returned data is an object do nothing, else try to parse
  var array = typeof objArray != 'object' ? JSON.parse(objArray) : objArray;

  // Remove empty items from fields array
  fields = $.grep(fields, function (n) {
    return (n);
  });

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
  var alt = '';
  for (var objid in array) {
    object = array[objid];
    id = object._id;
    time = prettyDateString(Date.parse(get_field_value(object,'@timestamp')) + tOffset);
    alt = i % 2 == 0 ? '' : 'alt'
    str += '<tr class="'+alt+' logrow" onclick=\'viewLog("' + objid + '")\'>';

    str += '<td class=firsttd>' + time + '</td>';
    for (var index in fields) {
      field = fields[index];
      value = get_field_value(object,field);
      value = value === undefined ? "-" : value.toString();
      str += '<td>' + xmlEnt(wbr(value, 10)) + '</td>';
    }
    str += '</tr><tr id=logrow_' + objid + ' class=hidedetails><td id=log_' +
      objid + ' colspan=100></td></tr>';
    i++;
  }

  str += '</tbody></table>';
  return str;
}

function viewLog(objid) {

  // Get the table
  str = details_table(objid)

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


// Create a table with details about an object
function details_table(objid,theme) {
  if (theme === undefined) theme = 'logdetails table-bordered';

  obj = window.resultjson.hits.hits[objid];
  obj_fields = get_object_fields(obj);
  str = "<table class='"+theme+"'>" +
    "<tr><th>Field</th><th>Action</th><th>Value</th></tr>";

  var field = '';
  var field_id = '';
  var value = '';
  var orig = '';
  var buttons = '';

  var i = 1;
  for (index in obj_fields) {
    field = obj_fields[index];
    field_id = field.replace('@', 'ATSYM');
    value = get_field_value(obj,field);
    buttons = "<i class='jlink icon-large icon-search' id=findthis_"+objid+"_"+field_id+"></i> " +
              "<i class='jlink icon-large icon-ban-circle' id=notthis_"+objid+"_"+field_id+"></i> ";

    if (isNaN(value)) {
      try {
        var json = JSON.parse(value);
        value = JSON.stringify(json,null,4);
        buttons = "";
      } catch(e) {
      }
    }

    trclass = (i % 2 == 0) ? 'class=alt' : '';
    str += "<tr " + trclass + ">" +
      "<td class='firsttd " + field_id + "_field'>" + field + "</td>" +
      "<td style='width: 60px'>" + buttons + "</td>" +
      '<td>' + xmlEnt(wbr(value, 10)) + "<span style='display:none'>" +
      xmlEnt(value) + "</span>" +
      "</td></tr>";
    i++;

    $("body").delegate(
      "#findthis_"+objid+"_"+field_id, "click", function (objid) {
        mSearch(
          $(this).parents().eq(1).find('.firsttd').text(),
          $(this).parents().eq(1).find('span').text()
        );
    });

    $("body").delegate(
      "#notthis_"+objid+"_"+field_id, "click", function (objid) {
        mSearch(
          "NOT " + $(this).parents().eq(1).find('.firsttd').text(),
          $(this).parents().eq(1).find('span').text()
        );
    });

  }
  str += "</table>";
  return str;
}


function mSearch(field, value, mode) {
  if (mode === undefined) mode = '';
  if (mode != 'analysis') {
    window.hashjson.mode = mode;
    window.hashjson.analyze_field = '';
  }
  var glue = $('#queryinput').val() != "" ? " AND " : " ";
  window.hashjson.search = $('#queryinput').val() + glue + field + ":" + "\"" +
    addslashes(value.toString()) + "\"";
  setHash(window.hashjson);
  scroll(0, 0);
}

function mFields(field) {

  // If the field is not in the hashjson, add it
  if ($.inArray(field, window.hashjson.fields) < 0) {
    window.hashjson.fields.push(field);
  } else {
  // Otherwise, remove it
    window.hashjson.fields = jQuery.grep(
      window.hashjson.fields, function (value) {
        return value != field;
      }
    );
  }

  // Remove empty items if they exist
  window.hashjson.fields = $.grep(window.hashjson.fields,function(n){
    return(n);
  });

  var str = "";
  for (var index in window.hashjson.fields) {
    str += "<a class='jlink mfield logfield_selected'>"
      + window.hashjson.fields[index] + "</a> ";
  }

  for (var index in window.all_fields) {
    if ($.inArray(window.all_fields[index].toString(),
      window.hashjson.fields) < 0) {
      str += "<a class='jlink mfield " +
        window.all_fields[index].toString().replace('@', 'ATSYM') +
        "_field '>" +
        window.all_fields[index].toString() + "</a> ";
    }
  }

  $('#fields').html("<h5><i class='icon-columns'></i> Columns</h5> " + str);

  $('#logs').html(CreateLogTable(
    window.resultjson.hits.hits, window.hashjson.fields, 'table logs table-condensed'));

  $('#feedlinks').html(feedLinks(window.hashjson));

  pageLinks();

}

function feedLinks(obj) {
  var str = "<a href=/rss/" +
    Base64.encode(JSON.stringify(obj)) +
    ">rss <i class='icon-rss'></i></a> "+
    "<a href=/export/" +
    Base64.encode(JSON.stringify(obj)) +
    ">export <i class='icon-hdd'></i></a> "+
    "<a href=/stream#" +
    Base64.encode(JSON.stringify(obj)) +
    ">stream <i class='icon-dashboard'></i></a>"
  return str;
}

// Split up log spaceless strings
// Str = string to split
// num = number of letters between <wbr> tags

function wbr(str, num) {
  str = htmlEntities(str);
  return str.replace(RegExp("(\\w{" + num + "}|[:;,])([\\w\"'])", "g"),
    function (all, text, char) {
      return text + "<del>&#8203;</del>" + char;
    }
  );
}
function htmlEntities(str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

$(function () {
  $('form').submit(function () {
    if (window.hashjson.search != $('#queryinput').val()) {
      window.hashjson.offset = 0;
      window.hashjson.search = $('#queryinput').val();
    }
    window.hashjson.stamp = new Date().getTime();

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
  window.location.hash = Base64.encode(JSON.stringify(json));
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
function renderDateTimePicker(from, to, force) {
  if (!$('#timechange').length || force == true) {
    var maxDateTime = new Date();
    // set to midnight of current day
    maxDateTime.setHours(23,59,59,999);
    $('#graphheader').html("<center>" +
      "<input size=19 id=timefrom class=hasDatePicker " +
      "type=text name=timefrom value='" + ISODateString(from) + "'> to " +
      "<input size=19 id=timeto class=hasDatePicker " +
      " type=text name=timeto value='" + ISODateString(to) + "'> " +
      "<i id='timechange' class='jlink' style='visibility: hidden' " +
      "> filter</i></center>"
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

    //tz_string = window.tOffset == 0 ? "+0" : window.tOffset
    // Give user a nice interface for selecting time ranges
    $("#timechange").click(function () {
      var time = {
        "from": ISODateString(Date.parse($('#timefrom').val())) + int_to_tz(window.tOffset),
        "to": ISODateString(Date.parse($('#timeto').val())) + int_to_tz(window.tOffset)
      };
      window.hashjson.offset = 0;
      window.hashjson.time = time;
      window.hashjson.timeframe = "custom";
      setHash(window.hashjson);
    });
  }
}

// WTF. Has to be a better way to do this. Hi Tyler.
function int_to_tz(offset) {
  hour = offset / 1000 / 3600
  var str = ""
  if (hour == 0) {
    str = "+0000"
  }
  if (hour < 0) {
    if (hour > -10)
      str = "-0" + (hour * -100)
    else
      str = "-" + (hour * -100)
  }
  if (hour > 0) {
    if (hour < 10)
      str = "+0" + (hour * 100)
    else
      str = "+" + (hour * 100)
  }
  str = str.substring(0,3) + ":" + str.substring(3);
  return str
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
  if(typeof window.resultjson.kibana.time !== 'undefined') {
    // add null value at time from.
    if(window.hashjson.timeframe != 'all') {
      from = Date.parse(window.resultjson.kibana.time.from) + tOffset
      array.push(
        Array(from, null));
    }
  }

  for (var index in data) {
    value = data[index][metric];
    array.push(Array(data[index].time + tOffset, value));
  }

  if(typeof window.resultjson.kibana.time !== 'undefined') {
    // add null value at time to.
    to = Date.parse(window.resultjson.kibana.time.to) + tOffset
    array.push(
      Array(to, null));
  }
  renderDateTimePicker((array[0][0]),(array[array.length -1][0]),true);


  // Make sure we get results before calculating graph stuff
  if (!jQuery.isEmptyObject(data)) {

    // Allow user to select ranges on graph.
    // Its this OR click, not both it seems.
    var intset = false;
    $('#graph').bind("plotselected", function (event, ranges) {
      if (!intset) {
        intset = true;
        var time = {
          "from": ISODateString(
            parseInt(ranges.xaxis.from.toFixed(0)))+int_to_tz(window.tOffset),
          "to": ISODateString(
            parseInt(ranges.xaxis.to.toFixed(0)))+int_to_tz(window.tOffset)
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
            item.pageX + 50, item.pageY, y + " at " + prettyDateString(x)
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
    $("#graph"), [
    {
      data: array,
      label: label + " per " + secondsToHms(parseInt(interval) / 1000)
    }
    ], {
      legend: { position: "nw" },
      series: {
        lines:  { show: false, fill: true },
        bars:   { show: true,  fill: 1, barWidth: interval / 1.7 },
        points: { show: false },
        color: color,
        shadowSize: 1
      },
      xaxis: {
        mode: "time",
        timeformat: "%H:%M:%S<br>%m/%d",
        label: "Datetime",
        color: "#000",
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

function prettyDateString(d) {

  d = new Date(parseInt(d));

  function pad(n) {
    return n < 10 ? '0' + n : n
  }
  return pad(d.getUTCMonth() + 1) + '/' +
    pad(d.getUTCDate()) + ' ' +
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
  var stg1 = value.replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\r\n/g, '<br/>')
    .replace(/\r/g, '<br/>')
    .replace(/\n/g, '<br/>')
    .replace(/\t/g, '&nbsp;&nbsp;&nbsp;&nbsp;')
    .replace(/  /g, '&nbsp;&nbsp;');

  return stg1.replace(/&lt;del&gt;/g, '<del>')
    .replace(/&lt;\/del&gt;/g, '</del>');
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

function showError(title,text) {
  blank_page();
  $('#logs').html("<h2>"+title+"</h2>"+text);

  // We have to use hashjson's time here since we won't
  // get a resultjson on error, usually
  if(typeof window.hashjson.time !== 'undefined') {
    renderDateTimePicker(
      Date.parse(window.hashjson.time.from),
      Date.parse(window.hashjson.time.to)
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
      '"timeframe":900,'+
      '"graphmode":"count"'+
    '}'
  );
  setHash(window.hashjson);
}

function get_object_fields(obj) {
  var field_array = [];
  for (field in obj._source['@fields']) {
    field_array.push(field);
  }
  for (field in obj._source) {
    if (field != '@fields')
      field_array.push(field);
  }
  return field_array.sort();
}

function get_all_fields(json) {
  var field_array = [];
  var obj_fields;
  for (hit in json.hits.hits) {
    obj_fields = get_object_fields(json.hits.hits[hit]);
    for (index in obj_fields) {
      if ($.inArray(obj_fields[index],field_array) < 0) {
        field_array.push(obj_fields[index]);
      }
    }
  }
  return field_array.sort();
}

function get_field_value(object,field) {
  value = field.charAt(0) == '@' ?
    object['_source'][field] : object['_source']['@fields'][field];

  if(typeof value === 'undefined')
    return '-'
  if($.isArray(value))
    return value.toString();
  if(typeof value === 'object' && value != null)
    return JSON.stringify(value,null,4)

  return value.toString();
}


 /**
   * Calculate a graph interval
   *
   * from:: Date object containing the start time
   * to::   Date object containing the finish time
   * size:: Calculate to approximately this many bars
   *
   */
function calculate_interval(from,to,size) {
  interval = round_interval((to - from)/size)
  return interval
}

function round_interval (interval) {
  switch (true) {
    case (interval <= 500):       return 100;
    case (interval <= 5000):      return 1000;
    case (interval <= 7500):      return 5000;
    case (interval <= 15000):     return 10000;
    case (interval <= 45000):     return 30000;
    case (interval <= 180000):    return 60000;
    case (interval <= 450000):    return 300000;
    case (interval <= 1200000):   return 600000;
    case (interval <= 2700000):   return 1800000;
    case (interval <= 7200000):  return 3600000;
    default:                      return 10800000;
  }
}

function secondsToHms(seconds){
    var numyears = Math.floor(seconds / 31536000);
    if(numyears){
        return numyears + 'y';
    }
    var numdays = Math.floor((seconds % 31536000) / 86400);
    if(numdays){
        return numdays + 'd';
    }
    var numhours = Math.floor(((seconds % 31536000) % 86400) / 3600);
    if(numhours){
        return numhours + 'h';
    }
    var numminutes = Math.floor((((seconds % 31536000) % 86400) % 3600) / 60);
    if(numminutes){
        return numminutes + 'm';
    }
    var numseconds = (((seconds % 31536000) % 86400) % 3600) % 60;
    if(numseconds){
        return numseconds + 's';
    }
    return 'less then a second'; //'just now' //or other string you like;
}




function bind_clicks() {

  // Side bar expand/collapse
  $('#sbctl').click(function () {
    var sb = $('#sidebar');
    if (sb.is(':visible')) {
      sbctl('hide');
    } else {
      sbctl('show');
    }
  });

  // Column selection
  $("body").delegate(
    ".mfield", "click", function () {
      mFields($(this).text());
  });

  // Reset button
  $("#resetall").click(function () {
    window.location.hash = '#';
  });


  // Time changes
  $('#timeinput').change(function () {
    window.hashjson.timeframe = $(this).val();
    if (window.hashjson.timeframe == "custom") {
      //Initialize the date picker with a 15 minute window into the past
      var d = new Date()
      var startDate = new Date(d - (15 * 60 * 1000));
      renderDateTimePicker(
        startDate.getTime(), d.getTime());
    }
  });

  // Analysis table search
  $("#logs").delegate("table.analysis tr td i.search", "click",
    function () {
      mSearch(
        window.hashjson.analyze_field, $(this).parents().eq(1).children().eq(1).text()
      );
    }
  );

  // Analysis table rescore
  $("#logs").delegate("table.analysis tr td i.rescore", "click",
    function () {
      mSearch(
        window.hashjson.analyze_field, $(this).parents().eq(1).children().eq(1).text(), 'analysis'
      );
    }
  );

  // Go back to the logs
  $("#logs").delegate("button#back_to_logs", "click",
    function () {
      window.hashjson.mode = '';
      window.hashjson.graphmode = 'count';
      window.hashjson.analyze_field = '';
      setHash(window.hashjson);
    });


  $("div.pagelinks").delegate("i.nextpage", "click",
    function () {
      window.hashjson.offset = window.hashjson.offset + window.resultjson.kibana.per_page;
      setHash(window.hashjson);
    });

  $("div.pagelinks").delegate("i.prevpage", "click",
    function () {
      window.hashjson.offset = window.hashjson.offset - window.resultjson.kibana.per_page;
      setHash(window.hashjson);
  });

  $("div.pagelinks").delegate("i.firstpage", "click",
    function () {
      window.hashjson.offset = 0;
      setHash(window.hashjson);
  });
}