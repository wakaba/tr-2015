<html t:params="$tr $app">
<t:include path=_macro.html.tm />
<title>Text sets - XXX - TR</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="../" rel=up><code itemprop=url><t:text value="$tr->url"></code></a></h1>
      <h2 title=Branch><a href="../" rel=bookmark><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
    </hgroup>
  </header>

  <section class=text-sets>
    <h1>Text sets</h1>
    <p class=status hidden><progress/> <span class=message>{status}</span>

    <table>
      <thead>
        <tr>
          <th>Directory
          <th>Last updated
          <th>Commit
          <th>
      </thead>
      <template class=text-set-row-template>
        <th><a data-href={text_set_url}><code class=path>{path}</code></a>
        <td><time class=modified>2000-01-01 00:00:00</time>
        <td><span class=commit-message>{message}</span>
        <td>
          <a data-href="{text_set_url}edits">Recent edits</a>
          <a data-href="{text_set_url}comments">Recent comments</a>
          <a data-href="{text_set_url}langs">Settings</a>
      </template>
      <tbody>
    </table>

    <details>
      <summary>Add a text set</summary>
      <form onsubmit=" location.href = './' + encodeURIComponent (elements.path.value) + '/langs'; return false ">
        <p>
          <label>Directory: <input name=path pattern="(?:/[0-9a-zA-Z_.-]+)+" title="/path/to/text-set" placeholder="/myapp/data"></label>
          <button type=submit>Create</button>
      </form>
    </details>

    <script src=/js/time.js />
    <script src=/js/core.js charset=utf-8 />
    <script>
      (function () {
        var status = document.querySelector ('.text-sets .status');
        showProgress ({init: true, message: 'Loading...'}, status);
        server ('GET', 'info.ndjson', null, function (res) {
          var sets = res.data.text_sets;
          var tbody = document.querySelector ('.text-sets table tbody');
          var template = document.querySelector ('.text-sets .text-set-row-template');
          for (var n in sets) {
            var set = sets[n];
            var tr = document.createElement ('tr');
            tr.innerHTML = template.innerHTML;
            if (set.selected) tr.className = 'selected';
            tr.setAttribute ('data-path', set.path);
            tr.onclick = function () { this.querySelector ('a').click () };
            tr.querySelector ('.path').textContent = set.path;
            tr.querySelector ('.commit-message').textContent = set.commit_message;
            tr.querySelector ('.modified').textContent = new Date (parseInt ((set.commit_author || {time: 0}).time) * 1000).toISOString ();
            var setURL = './' + encodeURIComponent (set.path) + '/';
            Array.prototype.forEach.call (tr.querySelectorAll ('a[data-href]'), function (a) {
              a.href = a.getAttribute ('data-href').replace (/\{text_set_url\}/g, setURL);
            });
            tbody.appendChild (tr);
          }
          new TER (tbody);
          status.hidden = true;
        }, function (json) {
          showError (json, status);
        }, function (json) {
          showProgress (json, status);
        });
      }) ();
    </script>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
<script src=/js/time.js />
<script> new TER (document.body) </script>
