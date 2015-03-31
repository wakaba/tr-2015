  function server (method, url, formdata, ondone, onerror, onprogress) {
    var xhr = new XMLHttpRequest;
    xhr.open ('POST', url, true);
    var nextChunk = 0;
    xhr.onreadystatechange = function () {
      if (xhr.readyState === 3 || xhr.readyState === 4) {
        if (xhr.status === 200) {
          var responses = xhr.responseText.split (/\n/);
          while (nextChunk + 1 < responses.length) {
            var chunk = JSON.parse (responses[nextChunk]);
            nextChunk += 2;
            if (chunk.status === 102) {
              onprogress (chunk);
            } else if (chunk.status === 200) {
              ondone (chunk);
            } else {
              onerror (chunk);
            }
          }
        } else { // status !== 200
          if (xhr.readyState === 4) {
            onerror ({status: xhr.status, message: xhr.statusText});
          }
        }
      }
    };
    xhr.send (formdata);
  } // server

  function showProgress (json, status) {
    if (json.message) {
      var statusMessage = status.querySelector ('.message');
      statusMessage.textContent = json.message;
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
      statusBar.hidden = false;
    }
    status.hidden = false;
  } // showProgress

  function showError (json, status) {
    status.hidden = false;
    var statusMessage = status.querySelector ('.message');
    statusMessage.textContent = json.message || json.status;
    var statusBar = status.querySelector ('progress');
    statusBar.hidden = true;
  } // showError

  function showDone (json, status) {
    status.hidden = false;
    var statusMessage = status.querySelector ('.message');
    statusMessage.textContent = json.message || json.status;
    var statusBar = status.querySelector ('progress');
    statusBar.hidden = true;
  } // showDone
