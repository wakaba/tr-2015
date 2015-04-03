<html t:params="$tr $tr_config $app">
<title>Import - XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (document.trModified) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="../../" rel="up up up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
      <h2 title=Branch><a href="../" rel="up up"><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
      <h3 title=Path><a href="./" rel=up><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></a></h3>
    </hgroup>
  </header>

  <section class=config>
    <h1>Import</h1>

    <form action=import.ndjson method=post enctype=multipart/form-data>
      <input type=hidden name=from value=file>
      <table class=config>
        <tr>
          <th><label for=import-file>Files</label>
          <td><input type=file name=file multiple id=import-file><!-- XXX accept=... -->

        <tr>
          <th><label for=import-lang>Language</label>
          <td>
            <select id=import-lang name=lang>
              <option value=en label=English>
              <option value=ja label=Japanese>
            </select>
        <tr>
          <th><label for=import-format>Input format</label>
          <td>
            <select id=import-format name=format>
              <option value=po>PO (GNU Gettext)
            </select>
        <tr>
          <th><label for=import-arg_format>Argument format</label>
          <td>
            <select id=import-arg_format name=arg_format>
              <option value=auto>Auto
              <option value=printf>printf
              <option value=percentn>%n
              <option value=braced>{placeholder}
            </select>
      </table>

      <p class=buttons><button type=submit>Import</button>
      <p class=status hidden><progress></progress> <span class=message></span>
    </form>
    <script src=/js/core.js charset=utf-8 />
    <script>
      Array.prototype.forEach.call (document.querySelector ('section.config').querySelectorAll ('form[method=post]'), function (form) {
        form.onsubmit = function () {
          var status = form.querySelector ('.status');
          showProgress ({init: true}, status);
          server ('POST', form.action, new FormData (form), function (res) {
            showDone (res, status);
          }, function (json) {
            showError (json, status);
          }, function (json) {
            showProgress (json, status);
          });
          return false;
        };
      });
    </script>
  </section>
</section>

<t:include path=_footer.html.tm m:app=$app />
