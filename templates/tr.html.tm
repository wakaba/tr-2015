<html t:params="$tr $app $branches">
<t:include path=_macro.html.tm />
<t:call x="use Wanage::URL">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>
<body>

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="./" rel=bookmark><code itemprop=url><t:text value="$tr->url"></code></a></h1>
    </hgroup>
  </header>

  <section id=branches>
    <h1>Branches</h1>

    <table class=branches>
      <thead>
        <tr>
          <th>Branch
          <th>Last updated
          <th>Commit
      <tbody>
        <t:for as=$branch x="[sort { $a->{name} cmp $b->{name} } values %$branches]">
          <tr onclick=" querySelector ('a[href]').click () ">
            <t:if x="$branch->{selected}"><t:class name="'default'"></t:if>
            <th><a pl:href="'./'.(percent_encode_c $branch->{name}).'/'"><code><t:text value="$branch->{name}"></code></a>
            <td><m:timestamp m:value="$branch->{commit_log}->{author}->{time}"/>
            <td><t:text value="$branch->{commit_message}">
        </t:for>
    </table>
  </section>

</section>

<t:include path=_footer.html.tm />
<script src=/js/time.js />
<script> new TER (document.body) </script>
