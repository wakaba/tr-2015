<html t:params="$tr $app $text_sets">
<t:include path=_macro.html.tm />
<t:call x="use Wanage::URL">
<title>XXX</title>
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

  <section id=text-sets>
    <h1>Text sets</h1>

    <table class=text-sets>
      <thead>
        <tr>
          <th>Directory
          <th>Last updated
          <th>Commit
          <th>
      <tbody>
        <t:for as=$text_set x="[sort { $a->{path} cmp $b->{cmp} } values %$text_sets]">
          <tr onclick=" querySelector ('a[href]').click () ">
            <th><a pl:href="'./'.(percent_encode_c $text_set->{path}).'/'"><code><t:text value="$text_set->{path}"></code></a>
            <td><m:timestamp m:value="$text_set->{commit_log}->{author}->{time}"/>
            <td><span class=commit-message><t:text value="$text_set->{commit_log}->{body}"></span>
            <td>
              <a pl:href="'./'.(percent_encode_c $text_set->{path}).'/edits'">Recent edits</a>
              <a pl:href="'./'.(percent_encode_c $text_set->{path}).'/comments'">Recent comments</a>
              <a pl:href="'./'.(percent_encode_c $text_set->{path}).'/config'">Settings</a>
        </t:for>
    </table>

    <details id=add-text-set>
      <summary>Add a text set</summary>
      <form onsubmit=" location.href = './' + encodeURIComponent (elements.path.value) + '/#config-langs'; return false ">
        <p>
          <label>Directory: <input name=path pattern="(?:/[0-9a-zA-Z_.-]+)+" title="/path/to/text-set" placeholder="/myapp/data"></label>
          <button type=submit>Create</button>
      </form>
    </details>
  </section>

</section>

<t:include path=_footer.html.tm />
<script src=/js/time.js />
<script> new TER (document.body) </script>
