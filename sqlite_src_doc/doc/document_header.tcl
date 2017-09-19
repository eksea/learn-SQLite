

proc document_header {title path {search {}}} {
  set ret [subst -nocommands {
  <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
  <html><head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
  <link href="${path}sqlite.css" rel="stylesheet">
  <title>$title</title>
  <!-- path=$path -->
  </head>
  }]

  if {[file exists DRAFT]} {
    set tagline {<font size="6" color="red">*** DRAFT ***</font>}
  } else {
    set tagline {Small. Fast. Reliable.<br>Choose any three.}
  }

  append ret [subst -nocommands {<body>
    <div class=nosearch>
      <a href="${path}index.html">
        <img class="logo" src="${path}images/sqlite370_banner.gif" alt="SQLite" border="0">
      </a>
      <div><!-- IE hack to prevent disappearing logo --></div>
      <div class="tagline desktoponly">
        $tagline
      </div>
      <div class="menu mainmenu">
        <ul>
          <li><a href="${path}index.html">Home</a>
          <li class='mobileonly'><a href="javascript:void(0)" onclick='toggle_div("submenu")'>Menu</a>
          <li class='wideonly'><a href='${path}about.html'>About</a>
          <li class='desktoponly'><a href="${path}docs.html">Documentation</a>
          <li class='desktoponly'><a href="${path}download.html">Download</a>
          <li class='wideonly'><a href='${path}copyright.html'>License</a>
          <li class='desktoponly'><a href="${path}support.html">Support</a>
          <li class='desktoponly'><a href="${path}prosupport.html">Purchase</a>
          <li class='search' id='search_menubutton'>
            <a href="javascript:void(0)" onclick='toggle_search()'>Search</a>
        </ul>
      </div>
      <div class="menu submenu" id="submenu">
        <ul>
          <li><a href='${path}about.html'>About</a>
          <li><a href='${path}docs.html'>Documentation</a>
          <li><a href='${path}download.html'>Download</a>
          <li><a href='${path}support.html'>Support</a>
          <li><a href='${path}prosupport.html'>Purchase</a>
        </ul>
      </div>
      <div class="searchmenu" id="searchmenu">
        <form method="GET" action="${path}search">
          <select name="s" id="searchtype">
            <option value="d">Search Documentation</option>
            <option value="c">Search Changelog</option>
          </select>
          <input type="text" name="q" id="searchbox" value="$search">
          <input type="submit" value="Go">
        </form>
      </div>
    </div>
  }]

  append ret [subst -nocommands {
    <script>
      function toggle_div(nm) {
        var w = document.getElementById(nm);
        if( w.style.display=="block" ){
          w.style.display = "none";
        }else{
          w.style.display = "block";
        }
      }

      function toggle_search() {
        var w = document.getElementById("searchmenu");
        if( w.style.display=="block" ){
          w.style.display = "none";
        } else {
          w.style.display = "block";
          setTimeout(function(){
            document.getElementById("searchbox").focus()
          }, 30);
        }
      }

      function div_off(nm){document.getElementById(nm).style.display="none";}
      window.onbeforeunload = function(e){div_off("submenu");}

      /* Disable the Search feature if we are not operating from CGI, since */
      /* Search is accomplished using CGI and will not work without it. */
      if( !location.origin.match || !location.origin.match(/http/) ){
        document.getElementById("search_menubutton").style.display = "none";
      }

      /* Used by the Hide/Show button beside syntax diagrams, to toggle the */
      /* display of those diagrams on and off */
      function hideorshow(btn,obj){
        var x = document.getElementById(obj);
        var b = document.getElementById(btn);
        if( x.style.display!='none' ){
          x.style.display = 'none';
          b.innerHTML='show';
        }else{
          x.style.display = '';
          b.innerHTML='hide';
        }
        return false;
      }
    </script>
    </div>
  }]

  regsub -all {\n+\s+} [string trim $ret] \n ret
  regsub -all {\s*/\*[- a-z0-9A-Z"*\n]+\*/} $ret {} ret
  return $ret
}
