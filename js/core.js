  function resolveURL (url, base) {
    try {
      var url = "" + new URL (url, base || "about:blank");
    } catch (e) {
      url = null;
    }
    return url;
  } // resolveURL

  function server (method, url, formdata, ondone, onerror, onprogress) {
    var xhr = new XMLHttpRequest;
    xhr.open (method, url, true);
    var nextChunk = 0;
    xhr.onreadystatechange = function () {
      if (xhr.readyState === 3 || xhr.readyState === 4) {
        if (xhr.status === 200 || xhr.status === 202) {
          if (/ndjson/.test (xhr.getResponseHeader ('Content-Type'))) {
            var responses = xhr.responseText.split (/\n/);
            while (nextChunk < responses.length - (xhr.readyState === 4 ? 0 : 1)) {
              var json = responses[nextChunk].replace (/^\s+/, '');
              nextChunk++;
              if (!json) return;
              var chunk = JSON.parse (json);
              if (!chunk) return;
              if (chunk.status === 102) {
                onprogress (chunk);
              } else if (chunk.status === 200 || chunk.status === 204) {
                ondone (chunk);
              } else {
                onerror (chunk);
              }
            }
          } else if (xhr.readyState === 4) {
            var json = JSON.parse (xhr.responseText);
            ondone ({status: xhr.status, message: xhr.statusText, data: json});
          }
        } else { // status !== 200
          if (xhr.readyState === 4) {
            if (xhr.status === 0) {
              onerror ({status: xhr.status, message: xhr.statusText || "Can't connect to the server"});
            } else {
              onerror ({status: xhr.status, message: xhr.statusText});
            }
          }
        }
      }
    };
    if (formdata === null || formdata instanceof FormData) {
      xhr.send (formdata);
    } else {
      xhr.setRequestHeader ('Content-Type', 'application/json');
      xhr.send (JSON.stringify (formdata));
    }
  } // server

  function showProgress (json, status) {
    if (json.secondary && !status.hidden) return;
    if (json.message) {
      var statusMessage = status.querySelector ('.message');
      if (json.onmessageclick) {
        statusMessage.innerHTML = '<a href=javascript:></a>';
        statusMessage.firstChild.onclick = json.onmessageclick;
        statusMessage.firstChild.textContent = json.message;
      } else {
        statusMessage.textContent = json.message;
      }
    } else if (json.init) {
      var statusMessage = status.querySelector ('.message');
      statusMessage.textContent = json.message || 'Processing...';
    }
    if (json.max) {
      var statusBar = status.querySelector ('progress');
      statusBar.max = json.max;
      if (json.value) statusBar.value = json.value;
    } else if (json.init) {
      var statusBar = status.querySelector ('progress');
      statusBar.removeAttribute ('value');
      statusBar.removeAttribute ('max');
      if (json.hideProgress) {
        statusBar.hidden = true;
      } else {
        statusBar.hidden = false;
      }
    }
    status.hidden = false;
    status.setAttribute ('data-type', 'progress');
  } // showProgress

  function showError (json, status) {
    status.hidden = false;
    var statusMessage = status.querySelector ('.message');
    statusMessage.textContent = json.message || json.status;
    var statusBar = status.querySelector ('progress');
    statusBar.hidden = true;
    (status.scrollIntoViewIfNeeded || status.scrollIntoView).call (status);
    status.setAttribute ('data-type', 'error');
  } // showError

  function showDone (json, status) {
    status.hidden = false;
    var statusMessage = status.querySelector ('.message');
    statusMessage.textContent = json.message || json.status;
    var statusBar = status.querySelector ('progress');
    statusBar.hidden = true;
    status.setAttribute ('data-type', 'done');
  } // showDone
