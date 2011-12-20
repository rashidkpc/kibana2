$(document).ready(function () {

    var d = new Date()
    window.tOffset = -d.getTimezoneOffset() * 60 * 1000;


    // Some click bindings
    $("#showAdvanced").click(function () {
        $('#header').height(200);
    });

    $("#resetall").click(function () {
        delete window.hashjson;
        tip("The reset button resets searches, fields and timeframes");
        window.location.hash = '#';
    });

    $('#timeinput').change(function() {
        window.hashjson.timeframe = $(this).val();
        delete window.hashjson.time;
    });

    // Basically, whenever the URL changes, fire this.
    $.history.init(pageload);

    console.log(window.location.hash);
    // Resize flot graph with window
    $(window).resize(function() {
        logGraph(window.graphdata,window.interval);
    });
//clearInterval(window.refreshIntervalId);
//window.refreshIntervalId = setInterval( "getPage()", 1000000 );	
});

// This gets called every time the URL changes,
// Including hash changes, this setHash() will 
// cause a reload of the results


function pageload(hash) {
    if (getcookie('username') != null) $('#menu').html('<a class="tab jlink" href="auth.php?logout">Logout</a>') 
    //if hash value exists, run the ajax
    if (hash) {
        window.hashjson = JSON.parse(base64Decode(hash));

        console.log("Sending: " + JSON.stringify(window.hashjson));

        // Take the hash data and populate the search fields
        $('#queryinput').val(window.hashjson.search);
        $('#fieldsinput').val(window.hashjson.fields);
        if(typeof window.hashjson.time !== 'undefined') {
            window.hashjson.timeframe = "custom";
        }
        $('#timeinput').val(window.hashjson.timeframe);
        getPage();
    } else {
        window.hashjson = JSON.parse('{"search":"","fields":[],"offset":0,"timeframe":"15 minutes"}');
        setHash(window.hashjson);
    }
}

function getPage() {
    if (window.inprogress) {
        return false;
    }
    window.inprogress = true;
    // Show the user an animated loading thingy
    $('#meta').html("<img src=images/ajax-loader.gif>");

    sendhash = window.location.hash.replace(/^#/, '');
    ;
    //var data = 'page=' + encodeURIComponent(sendhash);
    var data = 'page=' + sendhash;

    //Get the data and display it
    request = $.ajax({
        url: "loader2.php",
        type: "GET",
        data: data,
        cache: false,
        success: function (json) {
            // Make sure we're still on the same page 
            if (sendhash == window.location.hash.replace(/^#/, '')) {

                //Parse out the window hash
                window.resultjson = JSON.parse(json);

                $('#graphheader,#graph').text("");
                console.log(resultjson);
                console.log("DEBUG:" + resultjson.debug);

                // Make sure we get some result before doing anything
                if (resultjson.hits > 0) {
		
                    var fieldstr = "";
                    for(var index in window.hashjson.fields) {
                        fieldstr += "<a class='jlink logfield_selected' onClick='mFields(\"" + window.hashjson.fields[index] + "\")'>" + window.hashjson.fields[index] + "</a> ";
                    }
                    for(var index in resultjson.all_fields) {
                        if ($.inArray(resultjson.all_fields[index].toString(), window.hashjson.fields) < 0)
                            fieldstr += "<a class='jlink "+ resultjson.all_fields[index].toString().replace('@', 'ATSYM') + "_field ' onClick='mFields(\"" + resultjson.all_fields[index].toString() + "\")'>" + resultjson.all_fields[index].toString() + "</a> ";
                    }
                    $('#fields').html("Fields: " + fieldstr);

                    // Create and populate graph
                    $('#graph').html('<center><br><p><img src=images/barload.gif></center>');
                    getGraph(resultjson.graph.interval);

                    // Create and populate #logs table
                    $('#logs').html(CreateTableView(window.resultjson.results, resultjson.fields_requested, 'logs'));
                    pageLinks();

                } else {
                    $('#logs').html("No results match your query, give it another shot there champ.");
                }

                // Populate meta data
                $('#meta').html("<tr class=alt><td>Hits</td><td>" + addCommas(window.resultjson.hits) + "</td></tr>");
                $('#meta').append("<tr><td>Indexed</td><td>" + addCommas(resultjson.total) + "</td></tr>");

                console.log("QUERY: " + window.resultjson.elasticsearch_json);

                //$('#meta').append("<tr class=alt><td>Fields</td><td>"+window.resultjson.fields_requested+"</td></tr>");
                //display the body with fadeIn transition
                $('#logs').fadeIn('slow');
            }
        }
    });
    window.inprogress = false;
}

function getGraph(interval) {
    //generate the parameter for the php script
    var sendhash = window.location.hash.replace(/^#/, '');
    //var data = 'page=' + encodeURIComponent(sendhash) + "&mode=graph&interval=" + interval;
    var data = 'page=' + sendhash + "&mode=graph&interval=" + interval;
    //Get the data and display it
    request = $.ajax({
        url: "loader2.php",
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
                logGraph(graphjson.graph.data, window.interval);

            }
        }
    });
}

function pageLinks() {
    // Pagination
    var str = "<center>";
    if (window.hashjson.offset - 50 >= 0) {
        str += "<a class='jlink firstpage'>First</a> ";
        str += "<a class='jlink prevpage'>Prev</a> ";
    }
    var end = window.hashjson.offset + window.resultjson.page_count;
    str += " <strong>" + window.hashjson.offset + " TO " + end + "</strong> ";
    if (window.hashjson.offset + 50 < window.resultjson.hits) {
        str += "<a class='jlink nextpage'>Next</a> ";
    //str += "<a class='jlink lastpage'>Last</a> ";
    }
    str += "</center>";
   
    $('.pagelinks').html(str);

    $(".nextpage").click(function () {
        window.hashjson.offset = window.hashjson.offset + 50;
        setHash(window.hashjson);
    });

    $(".prevpage").click(function () {
        window.hashjson.offset = window.hashjson.offset - 50;
        setHash(window.hashjson);
    });

    $(".firstpage").click(function () {
        window.hashjson.offset = 0;
        setHash(window.hashjson);
    });
}

// This function creates a standard table with column/rows
// objArray = Anytype of object array, like JSON results
// fields = Of the fields returned, only display these
// theme (optional) = A css class to add to the table (e.g. <table class="<theme>">
// enableHeader (optional) = Controls if you want to hide/show, default is show


function CreateTableView(objArray, fields, theme, enableHeader) {
    // set optional theme parameter
    if (theme === undefined) {
        theme = 'mediumTable'; //default theme
    }

    if (enableHeader === undefined) {
        enableHeader = true; //default enable headers
    }

    if (objArray === undefined) {
        return "<br><center>Sorry, I couldn't find anything matching that query. Give it another shot there champ.</center><br>";
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
        str += (i % 2 == 0) ? '<tr class="alt logrow" onclick=\'viewLog("' + objid + '")\'>' : '<tr class="logrow" onclick=\'viewLog("' + objid + '")\'>';
        str += '<td class=firsttd>' + array[objid]['@cabin_time'] + '</td>';
        for (var index in fields) {
            tdvalue = array[objid][fields[index]] === undefined ? "-" : array[objid][fields[index]].toString();
            str += '<td>' + wbr(tdvalue, 10) + '</td>';
        }
        str += '</tr><tr id=logrow_' + objid + ' class=hidedetails><td id=log_' + objid + ' colspan=100></td></tr>';
        i++;
    }

    str += '</tbody></table>';
    return str;
}

function viewLog(objid) {
    obj = sortObj(window.resultjson.results[objid]);

    // Create a table of information about the log
    var str = "<table class=logdetails><tr><th>Field</th><th>Value</th></tr>";
    var i = 1;
    var selected = ""
    for (field in obj) {
        selected = "";
        if ($.inArray(field, window.hashjson.fields) > -1) {
            selected = "logfield_selected";
        }
        value = obj[field].toString();
        if(!(field.match(/^@cabin_/))) {
            trclass = (i % 2 == 0) ? 'class=alt' : '';
            str += "<tr " + trclass + ">";
            str += "<td class='logfield firsttd " + field.replace('@', 'ATSYM') + "_field " + selected + "' onClick='mFields(\"" + field + "\")'>" + field + "</td>";
            str += '<td>';
		
            str += wbr(value, 3);
            str += " <img src=images/plus.png class=jlink onClick='mSearch(\"" + field + "\",getField(\""+objid+"\",\""+field+"\"))'> "; 
            str += " <img src=images/minus.png class=jlink onClick='mSearch(\"NOT " + field + "\",getField(\""+objid+"\",\""+field+"\"))'>";
            str += "</td></tr>";
            i++;
        }
    }
    str += "</table>";

    // Populate td with that table
    $('#log_' + objid).html(str);

    // Regular jQuery toggle() doesn't work with table-rows
    $('#logrow_' + objid).toggleClass('showdetails');
    $('#logrow_' + objid).toggleClass('hidedetails');
}

function getField(objid,field) {
    obj = window.resultjson.results[objid];
    return obj[field];
}

function mSearch(field,value) {
    var glue = $('#queryinput').val() != "" ? " AND " : " ";
    window.hashjson.search = $('#queryinput').val() + glue + field + ":" + "\"" + addslashes(value.toString()) + "\"";
    setHash(window.hashjson);
    scroll(0,0);
}

function mFields(field) {
    if ($.inArray(field, window.hashjson.fields) < 0) {
        window.hashjson.fields.push(field);
    } else {
        window.hashjson.fields = jQuery.grep(window.hashjson.fields, function (value) {
            return value != field;
        });
    }
    $('#fieldsinput').val(window.hashjson.fields);
    var str = "";
    for(var index in window.hashjson.fields) {
        str += "<a class='jlink logfield_selected' onClick='mFields(\"" + window.hashjson.fields[index] + "\")'>" + window.hashjson.fields[index] + "</a> ";
    }
    for(var index in resultjson.all_fields) {
        if ($.inArray(resultjson.all_fields[index].toString(), window.hashjson.fields) < 0) 
            str += "<a class='jlink "+ resultjson.all_fields[index].toString().replace('@', 'ATSYM') + "_field ' onClick='mFields(\"" + resultjson.all_fields[index].toString() + "\")'>" + resultjson.all_fields[index].toString() + "</a> ";
    }
    $('#fields').html("Fields: " + str);
    $('td.' + field.replace('@', 'ATSYM') + '_field').toggleClass('logfield_selected');

    $('#logs').html(CreateTableView(window.resultjson.results, window.hashjson.fields, 'logs'));
    pageLinks();   
 
}

// Split up log spaceless strings
// Str = string to split
// num = number of letters between <wbr> tags


function wbr(str, num) {
    return str.replace(RegExp("(\\w{" + num + "})(\\w)", "g"), function (all, text, char) {
        return text + "<wbr>" + char;
    });
}

$(function () {
    $('form').submit(function () {
        $('#tips').text("");
        if (window.hashjson.search != $('#queryinput').val()) {
            //delete window.hashjson.time;
            window.hashjson.offset = 0;
            window.hashjson.search = $('#queryinput').val();
        }
        window.hashjson.fields = $('#fieldsinput').val().split(',');
        window.hashjson.timeframe =  $('#timeinput').val();


        // We have to re-trigger get page if someone clicks Search without changing anything
        if (window.location.hash == "#" + JSON.stringify(window.hashjson)) {
            getPage();
        } else {
            setHash(window.hashjson);
        }
        tip("Change fields in real time by selecting from the list under the search box.");
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


// Big horrible function for creating graphs
function logGraph(data, interval) {

    // Calculate the timezone offset. ES stores everything in UTC
    var d = new Date()
    var tOffset = -d.getTimezoneOffset() * 60 * 1000;

    // Recreate the array, recalculating the time, gross.
    var array = new Array();
    for (var index in data) {
        array.push(Array(data[index].time + tOffset, data[index].count));
    }

    // Make sure we get results before calculating graph stuff
    if (!(typeof data[0] === undefined)) {
        var from = data[0].time + parseInt(tOffset);
        var to = data[data.length - 1].time + parseInt(tOffset);
        $('#graphheader').html("<center><input size=19 id=timefrom class=hasDatePicker type=text name=timefrom value='" + ISODateString(from) + "'> to <input size=19 id=timeto class=hasDatePicker type=text name=timeto value='" + ISODateString(to) + "'> <a class=jlink style='visibility:hidden;' id=timechange><img src=images/search_red.png></a></center>");

        $('#timefrom,#timeto').datetimepicker({
            showSecond: true,
            timeFormat: 'hh:mm:ss',
            dateFormat: 'yy-mm-dd',
            separator: 'T',
            onSelect: function(dateText, inst){
                $('#timechange').css('visibility','visible');
            }
        });
	
        // Give user a nice interface for selecting time ranges
        $("#timechange").click(function () {
            var f = new Date($('#timefrom').val());
            var t = new Date($('#timeto').val());
            var time = {
                "from" : ISODateString(f.getTime()),
                "to" : ISODateString(t.getTime())
            };
            window.hashjson.offset = 0;
            window.hashjson.time = time;
            window.hashjson.timeframe = "custom";
            tip("When you're done with your custom timeframe,<br>use the drop down to search up-to-the-minute results");
            setHash(window.hashjson);
        });


        // Allow user to select ranges on graph. Its this OR click, not both it seems.
        var intset = false;
        $('#graph').bind("plotselected", function (event, ranges) {
            if (!intset) {
                intset = true;
                var time = {
                    "from": ISODateString(parseInt(ranges.xaxis.from.toFixed(0)) - parseInt(tOffset)),
                    "to": ISODateString(parseInt(ranges.xaxis.to.toFixed(0)) - parseInt(tOffset))
                };
                window.hashjson.offset = 0;
                window.hashjson.time = time;
                window.hashjson.timeframe = "custom";
                tip("When you're done with your custom timeframe,<br>use the drop down to search up-to-the-minute results");
                setHash(window.hashjson);
            }
        });
    }


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
                y = item.datapoint[1].toFixed(0);

                showTooltip(item.pageX, item.pageY, y + " events at " + ISODateString(x));
            }
        } else {
            $("#tooltip").remove();
            previousPoint = null;
        }
    });

    $.plot(
        $("#graph"), [{
            data: array,
            label: "Logs per " + (parseInt(interval) / 1000) + "s"
        }], {
            series: {
                lines: {
                    show: false,
                    fill: true
                },
                bars: {
                    show: true,
                    fill: true,
                    barWidth: interval,
                },
                points: {
                    show: false
                },
                color: "#5d6a6b",
                shadowSize: 0,
            },
            xaxis: {
                mode: "time",
                timeformat: "%H:%M:%S<br>%m/%d",
                label: "Datetime",
                color: "#000",
            },
            yaxis: {
                min: 0,
                color: "#000",
            },
            selection: {
                mode: "x"
            },
            grid: {
                backgroundColor: "#fff",
                color: "#5d6a6b",
                hoverable: true,
                clickable: true,
            }
        });

}


function showTooltip(x, y, contents) {
    $('<div id="tooltip">' + contents + '</div>').css({
        position: 'absolute',
        display: 'none',
        top: y + 5,
        left: x + 15,
        color: '#000',
        border: '1px solid #fff',
        padding: '3px',
        'font-size': '8pt',
        'background-color': '#fff',
        border: '1px solid #000',
        'font-family': '"Verdana", Geneva, sans-serif'
    }).appendTo("body").fadeIn(200);
}

// Create an ISO8601 compliant timestamp for ES

function ISODateString(unixtime) {
    d = new Date(parseInt(unixtime));

    function pad(n) {
        return n < 10 ? '0' + n : n
    }
    return d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1) + '-' + pad(d.getUTCDate()) + 'T' + pad(d.getUTCHours()) + ':' + pad(d.getUTCMinutes()) + ':' + pad(d.getUTCSeconds()) 
}


function is_int(value){
    if((parseFloat(value) == parseInt(value)) && !isNaN(value)){
        return true;
    } else {
        return false;
    }
}

function sortObj(arr){
    // Setup Arrays
    var sortedKeys = new Array();
    var sortedObj = {};

    // Separate keys and sort them
    for (var i in arr){
        sortedKeys.push(i);
    }
    sortedKeys.sort();

    // Reconstruct sorted obj based on keys
    for (var i in sortedKeys){
        sortedObj[sortedKeys[i]] = arr[sortedKeys[i]];
    }
    return sortedObj;
}


function tip(tip) {
    $('#tips').html('<img src=images/info.png> '+tip);
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
	for(var i=0;i < ca.length;i++) {
		var c = ca[i];
		while (c.charAt(0)==' ') c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
}
