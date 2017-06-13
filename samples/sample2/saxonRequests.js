// Copyright (c) Saxonica Limited 2017


// Make an asynchronous post request directly using XMLHttpRequest.
// urlVar is the destination URL
// data will be the request content
// contentType will be the request Content type
// callback is a function applied when the response has returned

var makePostRequestJS = function (urlVar, data, contentType, callback) {

    if (typeof XMLHttpRequest == "undefined") {
        XMLHttpRequest = function () {
            return new ActiveXObject("Msxml2.XMLHTTP.6.0");
        };
    }

    var http = new XMLHttpRequest();

    http.open("POST", urlVar, true);

    http.onreadystatechange = function () {
        if (http.readyState > 3 && http.status == 200) {
            console.log("responseURL is:" + http.responseURL);
            console.log("http.responseXML: " + http.responseXML);
            if (http.responseXML != null) {
                console.log("http.responseXML.children.length: " + http.responseXML.children.length);
                console.log("http.responseXML.firstElementChild: " + http.responseXML.firstElementChild);
            }
            callback(http);
        }
    };

    //Send the proper header information along with the request
    http.setRequestHeader("Content-type", contentType);

    http.send(data);

};


// Sends data in HTTP request content as text. When the response is received a new SaxonJS.transform is called,
// using the response content XML Node as the sourceNode.
// data is serialized $orderXML

var submitXMLorder2 = function (data) {

    var responseFn = function (response) {
        var responseContent = response.responseXML.firstElementChild;

        // responseContent is a Node, so it can be supplied to the sourceNode option of SaxonJS.transform

        SaxonJS.transform({
            "stylesheetLocation":"licenseTool.sef.xml",
            "sourceNode":responseContent,
            "initialTemplate":"orderReceived"
        });
    };

    makePostRequestJS("http://localhost:19757/license-tool/receive-order", data, "text/plain", responseFn);

};



           