//
// Routing request based on path and query information in the URL
//
// Additionally provides defaults for color and title, and 
// determines what buttons are required.
//
// Returns item, buttons, and options
function Router() {};

// route request based on path and query from the window location (URL)
Router.route = function(path, query) {
  var options = {};
  var buttons = [];
  var item, shepherd;

  if (!path || path == ".") {
    item = Agenda
  } else if (path == "search") {
    item = {view: Search, query: query}
  } else if (path == "comments") {
    item = {view: Comments}
  } else if (path == "backchannel") {
    item = {
      view: Backchannel,
      title: "Agenda Backchannel",
      online: Server.online
    }
  } else if (path == "queue") {
    item = {view: Queue, title: "Queued approvals and comments"};
    if (Server.role != "director") item.title = "Queued comments"
  } else if (path == "flagged") {
    item = {view: Flagged, title: "Flagged reports"}
  } else if (path == "missing") {
    item = {
      view: Missing,
      title: "Missing reports",
      buttons: [{form: InitialReminder}, {button: FinalReminder}]
    }
  } else if (new RegExp("^flagged/[-\\w]+$").test(path)) {
    item = Agenda.find(path.slice(8, path.length));
    options = {traversal: "flagged"}
  } else if (new RegExp("^queue/[-\\w]+$").test(path)) {
    item = Agenda.find(path.slice(6, path.length));
    options = {traversal: "queue"}
  } else if (new RegExp("^shepherd/queue/[-\\w]+$").test(path)) {
    item = Agenda.find(path.slice(15, path.length));
    options = {traversal: "shepherd"}
  } else if (new RegExp("^shepherd/\\w+$").test(path)) {
    shepherd = path.slice(9, path.length);

    item = {
      view: Shepherd,
      shepherd: shepherd,
      next: null,
      prev: null,
      title: "Shepherded by " + shepherd
    };

    // determine next/previous links
    Agenda.index.forEach(function(i) {
      var href;

      if (i.shepherd && i.comments) {
        if (i.shepherd.indexOf(" ") != -1) return;
        href = "shepherd/" + i.shepherd;

        if (i.shepherd > shepherd) {
          if (!item.next || item.next.href > href) {
            item.next = {title: i.shepherd, href: href}
          }
        } else if (i.shepherd < shepherd) {
          if (!item.prev || item.prev.href < href) {
            item.prev = {title: i.shepherd, href: href}
          }
        }
      }
    })
  } else if (path == "help") {
    item = {view: Help}
  } else if (path == "bootstrap.html") {
    item = {view: BootStrapPage, title: " "}
  } else if (path == "cache/") {
    item = {view: CacheStatus}
  } else if (new RegExp("^cache/").test(path)) {
    item = {view: CachePage}
  } else if (path == "fy22") {
    item = {
      view: FY22,
      title: "FY22 Budget Worksheet",
      color: "available",
      prev: {title: "Discussion Items", href: "Discussion-Items"},
      next: {title: "Action Items", href: "Action-Items"}
    }
  } else {
    item = Agenda.find(path);

    if (path == "Discussion-Items" && /^2017-02/.test(Agenda.date)) {
      item.next = {title: "FY22 Budget Worksheet", href: "fy22"}
    }
  };

  // bail unless an item was found
  if (!item) return {};

  // provide defaults for required properties
  item.color = item.color || "blank";
  item.title = item.title || item.view.displayName;

  // determine what buttons are required, merging defaults, form provided
  // overrides, and any overrides provided by the agenda item itself
  buttons = item.buttons;
  if (item.view.buttons) buttons = item.view.buttons().concat(buttons || []);

  if (buttons) {
    buttons = buttons.map(function(button) {
      var props = {
        text: "button",
        attrs: {className: "btn"},
        form: button.form
      };

      // form overrides
      var form = button.form;

      if (form && form.button) {
        for (var name in form.button) {
          if (name == "text") {
            props.text = form.button.text
          } else if (name == "class" || name == "classname") {
            props.attrs.className += " " + form.button[name].replace(/_/g, "-")
          } else {
            props.attrs[name.replace(/_/g, "-")] = form.button[name]
          }
        }
      } else {
        // no form or form has no separate button: so this is just a button
        delete props.text;
        props.type = button.button || form;
        props.attrs = {item: item, server: Server}
      };

      // item overrides
      for (var name in button) {
        if (name == "text") {
          props.text = button.text
        } else if (name == "class" || name == "classname") {
          props.attrs.className += " " + button[name].replace(/_/g, "-")
        } else if (name != "form") {
          props.attrs[name.replace(/_/g, "-")] = button[name]
        }
      };

      // clear modals
      if (typeof document !== 'undefined') {
        document.body.classList.remove("modal-open")
      };

      return props
    })
  };

  return {item: item, buttons: buttons, options: options}
};

//
// Respond to keyboard events
//
function Keyboard() {};

Keyboard.initEventHandlers = function() {
  // keyboard navigation (unless on the search screen)
  document.body.onkeydown = function(event) {
    if ($("#search-text")[0] || $(".modal-open")[0] || $(".modal.in")[0]) return;

    if (!event.altKey && ["input", "textarea"].indexOf(document.activeElement.tagName.toLowerCase()) != -1) {
      return
    };

    if (event.metaKey || event.ctrlKey) return;
    var link, info;

    if (event.keyCode == 37) {
      link = $("a[rel=prev]")[0];

      if (link) {
        link.click();
        return false
      }
    } else if (event.keyCode == 39) {
      link = $("a[rel=next]")[0];

      if (link) {
        link.click();
        return false
      }
    } else if (event.keyCode == 13) {
      link = $(".default")[0];
      if (link) Main.navigate(link.getAttribute("href"));
      return false
    } else if (event.keyCode == 67) {
      link = $("#comments")[0];

      if (link) {
        jQuery("html, body").animate({scrollTop: link.offsetTop}, "slow")
      } else {
        Main.navigate("comments")
      };

      return false
    } else if (event.keyCode == 73) {
      info = document.getElementById("info");
      if (info) info.click();
      return false
    } else if (event.keyCode == 77) {
      Main.navigate("missing");
      return false
    } else if (event.keyCode == 78) {
      $("#nav").click();
      return false
    } else if (event.keyCode == 65) {
      Main.navigate(".");
      return false
    } else if (event.keyCode == 83) {
      if (event.shiftKey) {
        Server.role = "secretary";
        Main.refresh()
      } else {
        link = $("#shepherd")[0];
        if (link) Main.navigate(link.getAttribute("href"))
      };

      return false
    } else if (event.keyCode == 88) {
      if (Main.item.attach && Minutes.started && !Minutes.complete) {
        Chat.changeTopic({
          user: Server.userid,
          link: Main.item.href,
          text: "current topic: " + Main.item.title
        });

        return false
      }
    } else if (event.keyCode == 81) {
      Main.navigate("queue");
      return false
    } else if (event.keyCode == 70) {
      Main.navigate("flagged");
      return false
    } else if (event.keyCode == 66) {
      Main.navigate("backchannel");
      return false
    } else if (event.shiftKey && event.keyCode == 191) {
      Main.navigate("help");
      return false
    } else if (event.keyCode == 82) {
      clock_counter++;
      Main.refresh();

      post("refresh", {agenda: Agenda.file}, function(response) {
        clock_counter--;
        Agenda.load(response.agenda, response.digest);
        Main.refresh()
      });

      return false
    } else if (event.keyCode == 61 || event.keyCode == 187) {
      Main.navigate("cache/");
      return false
    }
  }
};

// A convenient place to stash server data
var Server = {};

// controls display of clock in the header
var clock_counter = 0;

//
// function to assist with production of HTML and regular expressions
//
// Escape HTML characters so that raw text can be safely inserted as HTML
function htmlEscape(string) {
  return string.replace(htmlEscape.chars, function(c) {
    return htmlEscape.replacement[c]
  })
};

htmlEscape.chars = /[&<>]/g;
htmlEscape.replacement = {"&": "&amp;", "<": "&lt;", ">": "&gt;"};

// escape a string so that it can be used as a regular expression
function escapeRegExp(string) {
  // https://developer.mozilla.org/en/docs/Web/JavaScript/Guide/Regular_Expressions
  return string.replace(
    new RegExp("([.*+?^=!:${}()|\\[\\]/\\\\])", "g"),
    "\\$1"
  )
};

// Replace http[s] links in text with anchor tags
function hotlink(string) {
  return string.replace(hotlink.regexp, function(match, pre, link) {
    return pre + "<a href='" + link + "'>" + link + "</a>"
  })
};

hotlink.regexp = new RegExp("(^|[\\s.:;?\\-\\]<\\(])(https?://[-\\w;/?:@&=+$.!~*'()%,#]+[\\w/])(?=$|[\\s.:;,?\\-\\[\\]&\\)])", "g");

//
// Requests to the server
//
// "AJAX" style post request to the server, with a callback
function post(target, data, block) {
  var xhr = new XMLHttpRequest();
  xhr.open("POST", "../json/" + target, true);

  xhr.setRequestHeader(
    "Content-Type",
    "application/json;charset=utf-8"
  );

  xhr.responseType = "text";

  xhr.onreadystatechange = function() {
    var message;

    if (xhr.readyState == 4) {
      data = null;

      try {
        if (xhr.status == 200) {
          data = JSON.parse(xhr.responseText);
          if (data.exception) alert("Exception\n" + data.exception)
        } else if (xhr.status == 404) {
          alert("Not Found: json/" + target)
        } else if (xhr.status >= 400) {
          if (!xhr.response) {
            message = "Exception - " + xhr.statusText
          } else if (xhr.response.exception) {
            message = "Exception\n" + xhr.response.exception
          } else {
            message = "Exception\n" + JSON.parse(xhr.responseText).exception
          };

          console.log(message);
          alert(message)
        }
      } catch (e) {
        console.log(e)
      };

      block(data);
      Main.refresh()
    }
  };

  xhr.send(JSON.stringify(data))
};

// "AJAX" style get request to the server, with a callback
//
// Would love to use/build on 'fetch', but alas:
//
//   https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API#Browser_compatibility 
function retrieve(target, type, block) {
  var xhr = new XMLHttpRequest();

  xhr.onreadystatechange = function() {
    var data, message;

    if (xhr.readyState == 1) {
      clock_counter++;
      setTimeout(function() {Main.refresh()}, 0)
    } else if (xhr.readyState == 4) {
      data = null;

      try {
        if (xhr.status == 200) {
          if (type == "json") {
            data = xhr.response || JSON.parse(xhr.responseText)
          } else {
            data = xhr.responseText
          }
        } else if (xhr.status == 404) {
          alert("Not Found: " + type + "/" + target)
        } else if (xhr.status >= 400) {
          if (!xhr.response) {
            message = "Exception - " + xhr.statusText
          } else if (xhr.response.exception) {
            message = "Exception\n" + xhr.response.exception
          } else {
            message = "Exception\n" + JSON.parse(xhr.responseText).exception
          };

          console.log(message);
          alert(message)
        }
      } catch (e) {
        console.log(e)
      };

      block(data);
      clock_counter--;
      Main.refresh()
    }
  };

  if (/^https?:/.test(target)) {
    xhr.open("GET", target, true);
    if (type == "json") xhr.setRequestHeader("Accept", "application/json")
  } else {
    xhr.open("GET", "../" + type + "/" + target, true)
  };

  xhr.responseType = type;
  xhr.send()
};

//
// Reflow comments and lines
//
function Flow() {};

// reflow comment
Flow.comment = function(comment, initials, indent) {
  if (typeof indent === 'undefined') indent = "    ";
  var lines = comment.split("\n");
  var len = 71 - indent.length;

  for (var i = 0; i < lines.length; i++) {
    lines[i] = ((i == 0 ? initials + ": " : indent + " ")) + lines[i].replace(
      new RegExp("(.{1," + len + "})( +|$\\n?)|(.{1," + len + "})", "g"),
      "$1$3\n" + indent
    ).trim()
  };

  return lines.join("\n")
};

// reflow text
Flow.text = function(text, indent) {
  if (typeof indent === 'undefined') indent = "";

  // join consecutive lines (making exception for <markers> like <private>)
  text = text.replace(/([^\s>])\n(\w)/g, "$1 $2");

  // reflow each line
  var lines = text.split("\n");
  var len = 78 - indent.length;

  for (var i = 0; i < lines.length; i++) {
    indent = lines[i].match(/( *)(.?.?)(.*)/m);
    var n;

    if ((indent[1] == "" && indent[2] != "* ") || indent[3] == "") {
      // not indented (or short) -> split
      lines[i] = lines[i].replace(
        new RegExp("(.{1," + len + "})( +|$\\n?)|(.{1," + len + "})", "g"),
        "$1$3\n"
      ).replace(/[\n\r]+$/, "")
    } else {
      // preserve indentation.  indent[2] is the 'bullet' (if any) and is
      // only to be placed on the first line.
      n = 76 - indent[1].length;

      lines[i] = indent[3].replace(
        new RegExp("(.{1," + n + "})( +|$\\n?)|(.{1," + n + "})", "g"),
        indent[1] + "  $1$3\n"
      ).replace(indent[1] + "  ", indent[1] + indent[2]).replace(
        /[\n\r]+$/,
        ""
      )
    }
  };

  return lines.join("\n")
};

//
// Split comments string into individual comments
//
function splitComments(string) {
  var results = [];
  if (!string) return results;
  var comment = "";

  string.split("\n").forEach(function(line) {
    if (/^\S/.test(line)) {
      if (comment.length != 0) results.push(comment);
      comment = line
    } else {
      comment += "\n" + line
    }
  });

  if (comment.length != 0) results.push(comment);
  return results
};

//
// Main component, responsible for:
//
//  * Initial loading and polling of the agenda
//
//  * Rendering a Header, a item view, and a Footer
//
//  * Resizing view to leave room for the Header and Footer
//
var Main = React.createClass({
  displayName: "Main",
  statics: {refresh: function() {}},

  getInitialState: function() {
    return {}
  },

  // common layout for all pages: header, main, footer, and forms
  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      var view;

      if (!self.state.item) {
        $_.push(React.createElement("p", null, "Not found"))
      } else {
        $_.push(React.createElement(Header, {item: self.state.item}));
        view = null;

        $_.push(React.createElement("main", null, React.createElement(
          self.state.item.view,

          {item: self.state.item, ref: function(component) {
            Main.view = component
          }}
        )));

        $_.push(React.createElement(Footer, {
          item: self.state.item,
          buttons: self.state.buttons,
          options: self.state.options
        }));

        // emit hidden forms associated with the buttons displayed on this page
        if (self.state.buttons) {
          self.state.buttons.forEach(function(button) {
            if (button.form) {
              $_.push(React.createElement(
                button.form,
                {item: self.state.item, server: Server, button: button}
              ))
            }
          })
        }
      };

      return $_
    }())
  },

  // initial load of the agenda, and route first request
  componentWillMount: function() {
    // copy server info for later use
    for (var prop in this.props.server) {
      Server[prop] = this.props.server[prop]
    };

    Agenda.load(this.props.page.parsed, this.props.page.digest);
    Minutes.load(this.props.page.minutes);
    this.route(this.props.page.path, this.props.page.query);

    // free memory
    this.props.page.parsed = null
  },

  // encapsulate calls to the router
  route: function(path, query) {
    var route = Router.route(path, query);

    this.setState({
      item: route.item,
      buttons: route.buttons,
      options: route.options
    });

    if (!Main.item || Main.item.view != route.item.view) Main.view = null;
    Main.item = route.item
  },

  // navigation method that updates history (back button) information
  navigate: function(path, query) {
    history.state.scrollY = window.scrollY;
    history.replaceState(history.state, null, history.path);
    Main.scrollTo = 0;
    this.route(path, query);
    history.pushState({path: path, query: query}, null, path);
    window.onresize()
  },

  // refresh the current page
  refresh: function() {
    this.route(history.state.path, history.state.query)
  },

  // additional client side initialization
  componentDidMount: function() {
    var self = this;

    // export navigate and refresh methods
    Main.navigate = this.navigate;
    Main.refresh = this.refresh;

    // store initial state in history, taking care not to overwrite
    // history set by the Search component.
    var path, base;

    if (!history.state || !history.state.query) {
      path = this.props.page.path;

      if (path == "bootstrap.html") {
        path = document.location.href;
        base = document.getElementsByTagName("base")[0].href;
        if (path.substring(0, base.length) == base) path = path.slice(base.length)
      };

      history.replaceState({path: path}, null, path)
    };

    // listen for back button, and re-route/re-render when it occcurs
    window.addEventListener("popstate", function(event) {
      if (event.state && typeof event.state.path !== 'undefined') {
        Main.scrollTo = event.state.scrollY || 0;
        self.route(event.state.path, event.state.query)
      }
    });

    // start watching keystrokes
    Keyboard.initEventHandlers();

    // whenever the window is resized, adjust margins of the main area to
    // avoid overlapping the header and footer areas
    window.onresize = function() {
      var main = document.getElementsByTagName("main")[0];

      if (window.innerHeight <= 400 && document.body.scrollHeight > window.innerHeight) {
        document.querySelector("footer").style.position = "relative";
        document.querySelector("header").style.position = "relative";
        main.style.marginTop = 0;
        main.style.marginBottom = 0
      } else {
        document.querySelector("footer").style.position = "fixed";
        document.querySelector("header").style.position = "fixed";
        main.style.marginTop = document.querySelector("header.navbar").clientHeight + "px";
        main.style.marginBottom = document.querySelector("footer.navbar").clientHeight + "px"
      };

      if (Main.scrollTo == 0 || Main.scrollTo) {
        if (Main.scrollTo == -1) {
          jQuery("html, body").animate(
            {scrollTop: document.documentElement.scrollHeight},
            "fast"
          )
        } else {
          window.scrollTo(0, Main.scrollTo);
          Main.scrollTo = null
        }
      }
    };

    // do an initial resize
    Main.scrollTo = 0;
    window.onresize();

    // if agenda is stale, fetch immediately; otherwise save etag
    Agenda.fetch(this.props.page.etag, this.props.page.digest);

    // start Service Worker
    if (PageCache.enabled) PageCache.register();

    // start backchannel
    Events.monitor()
  },

  // after each subsequent re-rendering, resize main window
  componentDidUpdate: function() {
    window.onresize()
  }
});

//
// Header: title on the left, dropdowns on the right
//
// Also keeps the window/tab title in sync with the header title
//
// Finally: make info dropdown status 'sticky'
var Header = React.createClass({
  displayName: "Header",

  getInitialState: function() {
    return {infodropdown: null}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [
        "header",
        {className: "navbar navbar-fixed-top " + (self.props.item.color || "")}
      ];

      $_.push(React.createElement(
        "div",
        {className: "navbar-brand"},
        self.props.item.title
      ));

      if (/^7/.test(self.props.item.attach) && /^Establish /.test(self.props.item.title)) {
        $_.push(React.createElement(
          PodlingNameSearch,
          {item: self.props.item}
        ))
      };

      if (clock_counter > 0) {
        $_.push(React.createElement("span", {id: "clock"}, "⌛"))
      };

      $_.push(React.createElement.apply(React, function() {
        var $_ = ["ul", {className: "nav nav-pills navbar-right"}];

        // pending count
        if (Pending.count > 0) {
          $_.push(React.createElement(
            "li",
            {className: "label label-danger"},
            React.createElement(Link, {text: Pending.count, href: "queue"})
          ))
        };

        // 'info'/'online' dropdown
        //
        if (self.props.item.attach) {
          $_.push(React.createElement(
            "li",
            {className: "report-info dropdown " + (self.state.infodropdown || "")},

            React.createElement(
              "a",
              {className: "dropdown-toggle", id: "info", onClick: self.toggleInfo},
              "info",
              React.createElement("b", {className: "caret"})
            ),

            React.createElement(
              Info,
              {item: self.props.item, position: "dropdown-menu"}
            )
          ))
        } else if (self.props.item.online) {
          $_.push(React.createElement(
            "li",
            {className: "dropdown"},

            React.createElement(
              "a",
              {className: "dropdown-toggle", id: "info", "data-toggle": "dropdown"},
              "online",
              React.createElement("b", {className: "caret"})
            ),

            React.createElement.apply(React, function() {
              var $_ = ["ul", {className: "online dropdown-menu"}];

              self.props.item.online.forEach(function(id) {
                $_.push(React.createElement(
                  "li",
                  null,
                  React.createElement("a", {href: "/roster/committer/" + id}, id)
                ))
              });

              return $_
            }())
          ))
        } else {
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["li", {className: "dropdown"}];

            $_.push(React.createElement(
              "a",
              {className: "dropdown-toggle", id: "info", "data-toggle": "dropdown"},
              "summary",
              React.createElement("b", {className: "caret"})
            ));

            var summary = self.props.item.summary || Agenda.summary;

            $_.push(React.createElement.apply(React, function() {
              var $_ = [
                "table",
                {className: "table-bordered online dropdown-menu"}
              ];

              summary.forEach(function(status) {
                var text = status.text;
                if (status.count == 1) text = text.replace(/s$/, "");

                $_.push(React.createElement(
                  "tr",
                  {className: status.color},

                  React.createElement(
                    "td",
                    null,
                    React.createElement(Link, {text: status.count, href: status.href})
                  ),

                  React.createElement(
                    "td",
                    null,
                    React.createElement(Link, {text: text, href: status.href})
                  )
                ))
              });

              return $_
            }()));

            return $_
          }()))
        };

        // 'navigation' dropdown
        //
        $_.push(React.createElement(
          "li",
          {className: "dropdown"},

          React.createElement(
            "a",
            {className: "dropdown-toggle", id: "nav", "data-toggle": "dropdown"},
            "navigation",
            React.createElement("b", {className: "caret"})
          ),

          React.createElement.apply(React, function() {
            var $_ = ["ul", {className: "dropdown-menu"}];

            $_.push(React.createElement(
              "li",
              null,
              React.createElement(Link, {id: "agenda", text: "Agenda", href: "."})
            ));

            Agenda.index.forEach(function(item) {
              if (item.index) {
                $_.push(React.createElement(
                  "li",
                  null,
                  React.createElement(Link, {text: item.index, href: item.href})
                ))
              }
            });

            $_.push(React.createElement("li", {className: "divider"}));

            $_.push(React.createElement(
              "li",
              null,
              React.createElement(Link, {text: "Search", href: "search"})
            ));

            $_.push(React.createElement(
              "li",
              null,
              React.createElement(Link, {text: "Comments", href: "comments"})
            ));

            var shepherd = Agenda.shepherd;

            if (shepherd) {
              $_.push(React.createElement("li", null, React.createElement(
                Link,
                {id: "shepherd", text: "Shepherd", href: "shepherd/" + shepherd}
              )))
            };

            $_.push(React.createElement("li", null, React.createElement(
              Link,
              {id: "queue", text: "Queue", href: "queue"}
            )));

            $_.push(React.createElement("li", {className: "divider"}));

            $_.push(React.createElement("li", null, React.createElement(
              Link,
              {id: "backchannel", text: "Backchannel", href: "backchannel"}
            )));

            $_.push(React.createElement(
              "li",
              null,
              React.createElement(Link, {id: "help", text: "Help", href: "help"})
            ));

            return $_
          }())
        ));

        return $_
      }()));

      return $_
    }())
  },

  // set history on initial rendering
  componentDidMount: function() {
    this.componentDidUpdate()
  },

  // update title to match the item title whenever page changes
  componentDidUpdate: function() {
    var title = document.getElementsByTagName("title")[0];

    if (title.textContent != this.props.item.title) {
      title.textContent = this.props.item.title
    }
  },

  // toggle info dropdown
  toggleInfo: function() {
    return this.setState({infodropdown: (this.state.infodropdown ? null : "open")})
  }
});

//
// Layout footer consisting of a previous link, any number of buttons,
// followed by a next link.
//
// Overrides previous and next links when traversal is queue, shepherd, or
// Flagged.  Injects the flagged items into the flow once the meeting starts
// (last additional officer <-> first flagged &&
//  last flagged <-> first Special order)
//
var Footer = React.createClass({
  displayName: "Footer",

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [
        "footer",
        {className: "navbar navbar-fixed-bottom " + (self.props.item.color || "")}
      ];

      //
      // Previous link
      //
      var link = self.props.item.prev;
      var prefix = "";

      if (self.props.options.traversal == "queue") {
        prefix = "queue/";

        while (link && !link.ready_for_review(Server.initials)) {
          link = link.prev
        };

        link = link || {href: "../queue", title: "Queue"}
      } else if (self.props.options.traversal == "shepherd") {
        prefix = "shepherd/queue/";

        while (link && link.shepherd != self.props.item.shepherd) {
          link = link.prev
        };

        link = link || {
          href: "../" + self.props.item.shepherd,
          title: "Shepherd"
        }
      } else if (self.props.options.traversal == "flagged") {
        prefix = "flagged/";

        while (link && !link.flagged) {
          link = link.prev
        };

        if (!link) {
          if (Minutes.started) {
            link = Agenda.index.find(function(item) {
              return item.attach == "A"
            }).prev;

            prefix = ""
          };

          link = link || {href: "../flagged", title: "Flagged"}
        }
      } else if (Minutes.started && /\d/.test(self.props.item.attach) && link && /^[A-Z]/.test(link.attach)) {
        Agenda.index.forEach(function(item) {
          if (item.flagged) {
            prefix = "flagged/";
            link = item
          }
        })
      };

      if (link) {
        $_.push(React.createElement(Link, {
          className: "backlink navbar-brand " + (link.color || ""),
          text: link.title,
          rel: "prev",
          href: prefix + link.href
        }))
      } else if (self.props.item.prev || self.props.item.next) {
        // without this, Chrome will sometimes make the footer too tall
        $_.push(React.createElement("a", {className: "navbar-brand"}))
      };

      //
      // Buttons
      //
      $_.push(React.createElement.apply(React, function() {
        var $_ = ["span", null];

        if (self.props.buttons) {
          self.props.buttons.forEach(function(button) {
            if (button.text) {
              $_.push(React.createElement("button", button.attrs, button.text))
            } else if (button.type) {
              $_.push(React.createElement(button.type, button.attrs))
            }
          })
        };

        return $_
      }()));

      //
      // Next link
      //
      link = self.props.item.next;

      if (self.props.options.traversal == "queue") {
        while (link && !link.ready_for_review(Server.initials)) {
          link = link.next
        };

        link = link || {href: "queue", title: "Queue"}
      } else if (self.props.options.traversal == "shepherd") {
        while (link && link.shepherd != self.props.item.shepherd) {
          link = link.next
        };

        link = link || {
          href: "shepherd/" + self.props.item.shepherd,
          title: "shepherd"
        }
      } else if (self.props.options.traversal == "flagged") {
        prefix = "flagged/";

        while (link && !link.flagged) {
          if (Minutes.started && link.index) {
            prefix = "";
            break
          } else {
            link = link.next
          }
        };

        link = link || {href: "flagged", title: "Flagged"}
      } else if (Minutes.started && link && link.attach == "A") {
        while (link && !link.flagged && /^[A-Z]/.test(link.attach)) {
          link = link.next
        };

        if (link && /^[A-Z]/.test(link.attach)) prefix = "flagged/"
      };

      if (link) {
        if (!/^[A-Z]/.test(link.attach)) prefix = "";

        $_.push(React.createElement(Link, {
          className: "nextlink navbar-brand " + (link.color || ""),
          text: link.title,
          rel: "next",
          href: prefix + link.href
        }))
      } else if (self.props.item.prev || self.props.item.next) {
        // without this, Chrome will sometimes make the footer too tall
        $_.push(React.createElement(
          "a",
          {className: "nextarea navbar-brand"}
        ))
      };

      return $_
    }())
  }
});

//
// Secretary version of Adjournment section: shows todos
//
var Adjournment = React.createClass({
  displayName: "Adjournment",

  getInitialState: function() {
    this.state = {};

    Todos.set({
      add: [],
      remove: [],
      establish: [],
      feedback: [],
      minutes: {},
      loading: true,
      fetched: false
    });

    return this.state
  },

  render: function() {
    var self = this;

    return React.createElement(
      "section",
      {className: "flexbox"},

      React.createElement.apply(React, function() {
        var $_ = ["section", null];

        $_.push(React.createElement(
          "pre",
          {className: "report"},
          self.props.item.text
        ));

        if (!Todos.loading || Todos.fetched) {
          $_.push(React.createElement("h3", null, "Post Meeting actions"));

          if (Todos.add.length == 0 && Todos.remove.length == 0 && Todos.establish.length == 0) {
            if (Todos.loading) {
              $_.push(React.createElement("em", null, "Loading..."))
            } else {
              $_.push(React.createElement("p", {className: "comment"}, "complete"))
            }
          }
        };

        if (Todos.add.length != 0) {
          $_.push(React.createElement(TodoActions, {action: "add"}))
        };

        if (Todos.remove.length != 0) {
          $_.push(React.createElement(TodoActions, {action: "remove"}))
        };

        if (Todos.establish.length != 0) {
          $_.push(React.createElement(EstablishActions, {action: "remove"}))
        };

        if (Todos.feedback.length != 0) $_.push(React.createElement(FeedbackReminder));

        // display a list of completed actions
        var completed = Todos.minutes.todos;

        if (completed && Object.keys(completed).length > 0 && ((completed.added && completed.added.length != 0) || (completed.removed && completed.removed.length != 0) || (completed.established && completed.established.length != 0) || (completed.feedback_sent && completed.feedback_sent.length != 0))) {
          $_.push(React.createElement("h3", null, "Completed actions"));

          if (completed.added && completed.added.length != 0) {
            $_.push(React.createElement("p", null, "Added to PMC chairs"));

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["ul", null];

              completed.added.forEach(function(id) {
                $_.push(React.createElement("li", null, React.createElement(
                  "a",
                  {href: "../../../roster/committer/" + id},
                  id
                )))
              });

              return $_
            }()))
          };

          if (completed.removed && completed.removed.length != 0) {
            $_.push(React.createElement("p", null, "Removed from PMC chairs"));

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["ul", null];

              completed.removed.forEach(function(id) {
                $_.push(React.createElement("li", null, React.createElement(
                  "a",
                  {href: "../../../roster/committer/" + id},
                  id
                )))
              });

              return $_
            }()))
          };

          if (completed.established && completed.established.length != 0) {
            $_.push(React.createElement("p", null, "Established PMCs"));

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["ul", null];

              completed.established.forEach(function(pmc) {
                $_.push(React.createElement("li", null, React.createElement(
                  "a",
                  {href: "../../../roster/committee/" + pmc},
                  pmc
                )))
              });

              return $_
            }()))
          };

          if (completed.feedback_sent && completed.feedback_sent.length != 0) {
            $_.push(React.createElement("p", null, "Sent feedback"));

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["ul", null];

              completed.feedback_sent.forEach(function(pmc) {
                $_.push(React.createElement("li", null, React.createElement(
                  Link,
                  {text: pmc, href: pmc.replace(/\s+/g, "-")}
                )))
              });

              return $_
            }()))
          }
        };

        return $_
      }()),

      React.createElement.apply(React, function() {
        var $_ = ["section", null];
        var minutes = Minutes.get(self.props.item.title);

        if (minutes) {
          $_.push(React.createElement("h3", null, "Minutes"));
          $_.push(React.createElement("pre", {className: "comment"}, minutes))
        };

        return $_
      }())
    )
  },

  componentDidMount: function() {
    this.componentDidUpdate()
  },

  // fetch secretary todos once the minutes are complete
  componentDidUpdate: function() {
    if (Minutes.complete && Todos.loading && !Todos.fetched) {
      Todos.fetched = true;

      retrieve("secretary-todos/" + Agenda.title, "json", function(todos) {
        Todos.set(todos);
        Todos.loading = false
      })
    }
  }
});

//#######################################################################
//                          Add, Remove chairs                          #
//#######################################################################
var TodoActions = React.createClass({
  displayName: "TodoActions",

  getInitialState: function() {
    return {checked: {}, disabled: true, people: []}
  },

  // update on first update
  // update on first update
  componentDidMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // update check marks based on current Todo list
  componentWillReceiveProps: function($$props) {
    var self = this;
    var $people = this.state.people;
    $people = Todos[$$props.action];

    // uncheck people who were removed
    for (var id in this.state.checked) {
      if (!$people.some(function(person) {
        return person.id == id
      })) this.state.checked[id] = false
    };

    // check people who were added
    $people.forEach(function(person) {
      if (self.state.checked[person.id] == undefined) {
        if (!person.resolution || Minutes.get(person.resolution) != "tabled") {
          self.state.checked[person.id] = true
        }
      }
    });

    this.refresh();
    this.setState({people: $people})
  },

  refresh: function() {
    // disable button if nobody is checked
    var disabled = true;

    for (var id in this.state.checked) {
      if (this.state.checked[id]) disabled = false
    };

    this.setState({disabled: disabled});
    this.forceUpdate()
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];

      if (self.props.action == "add") {
        $_.push(React.createElement(
          "p",
          null,
          "Add to pmc-chairs and email welcome message:"
        ))
      } else {
        $_.push(React.createElement("p", null, "Remove from pmc-chairs:"))
      };

      $_.push(React.createElement.apply(React, function() {
        var $_ = ["ul", {className: "checklist"}];

        self.state.people.forEach(function(person) {
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["li", null];

            $_.push(React.createElement("input", {
              type: "checkbox",
              checked: self.state.checked[person.id],

              onChange: function() {
                self.state.checked[person.id] = !self.state.checked[person.id];
                self.refresh()
              }
            }));

            $_.push(React.createElement(
              "a",
              {href: "/roster/committer/" + person.id},
              person.id
            ));

            $_.push(" (" + person.name + ")");
            var resolution;

            if (self.props.action == "add" && person.resolution) {
              resolution = Minutes.get(person.resolution);

              if (resolution) {
                $_.push(" - ");

                $_.push(React.createElement(
                  Link,
                  {text: resolution, href: Todos.link(person.resolution)}
                ))
              }
            };

            return $_
          }()))
        });

        return $_
      }()));

      $_.push(React.createElement(
        "button",

        {
          className: "checklist btn btn-default",
          disabled: self.state.disabled,
          onClick: self.submit
        },

        "Submit"
      ));

      return $_
    }())
  },

  submit: function() {
    var self = this;
    this.setState({disabled: true});
    var data = {};
    data[this.props.action] = this.state.checked;

    post("secretary-todos/" + Agenda.title, data, function(todos) {
      self.setState({disabled: false});
      Todos.set(todos)
    })
  }
});

//#######################################################################
//                          Establish actions                           #
//#######################################################################
var EstablishActions = React.createClass({
  displayName: "EstablishActions",

  getInitialState: function() {
    return {checked: {}, disabled: true, podlings: []}
  },

  componentDidMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // update check marks based on current Todo list
  componentWillReceiveProps: function($$props) {
    var self = this;
    var $podlings = this.state.podlings;
    $podlings = Todos.establish;

    // uncheck podlings that were removed
    for (var name in this.state.checked) {
      if (!$podlings.some(function(podling) {
        return podling.name == name
      })) this.state.checked[name] = false
    };

    // check podlings that were added
    $podlings.forEach(function(podling) {
      if (self.state.checked[podling.name] == undefined) {
        if (!podling.resolution || Minutes.get(podling.resolution) != "tabled") {
          self.state.checked[podling.name] = true
        }
      }
    });

    this.refresh();
    this.setState({podlings: $podlings})
  },

  refresh: function() {
    // disable button if nobody is checked
    var disabled = true;

    for (var id in this.state.checked) {
      if (this.state.checked[id]) disabled = false
    };

    this.setState({disabled: disabled});
    this.forceUpdate()
  },

  render: function() {
    var self = this;

    return React.createElement(
      "span",
      null,

      React.createElement("p", null, React.createElement(
        "a",
        {href: "https://infra.apache.org/officers/tlpreq"},
        "Establish pmcs:"
      )),

      React.createElement.apply(React, function() {
        var $_ = ["ul", {className: "checklist"}];

        self.state.podlings.forEach(function(podling) {
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["li", null];

            $_.push(React.createElement("input", {
              type: "checkbox",
              checked: self.state.checked[podling.name],

              onChange: function() {
                self.state.checked[podling.name] = !self.state.checked[podling.name];
                self.refresh()
              }
            }));

            $_.push(React.createElement("span", null, podling.name));
            var resolution = Minutes.get(podling.resolution);

            if (resolution) {
              $_.push(" - ");

              $_.push(React.createElement(
                Link,
                {text: resolution, href: Todos.link(podling.resolution)}
              ))
            };

            return $_
          }()))
        });

        return $_
      }()),

      React.createElement(
        "button",

        {
          className: "checklist btn btn-default",
          disabled: this.state.disabled,
          onClick: this.submit
        },

        "Submit"
      )
    )
  },

  submit: function() {
    var self = this;
    this.setState({disabled: true});
    var data = {establish: this.state.checked};

    post("secretary-todos/" + Agenda.title, data, function(todos) {
      self.setState({disabled: false});
      Todos.set(todos)
    })
  }
});

//#######################################################################
//                      Reminder to draft feedback                      #
//#######################################################################
var FeedbackReminder = React.createClass({
  displayName: "FeedbackReminder",

  render: function() {
    return React.createElement(
      "span",
      null,
      React.createElement("p", null, "Draft feedback:"),

      React.createElement.apply(React, function() {
        var $_ = ["ul", {className: "list-group row"}];

        Todos.feedback.forEach(function(pmc) {
          $_.push(React.createElement(
            "li",
            {className: "list-group-item col-xs-6 col-sm-4 col-md-3 col-lg-2"},

            React.createElement(
              Link,
              {text: pmc, href: pmc.replace(/\s+/g, "-")}
            )
          ))
        });

        return $_
      }()),

      React.createElement(
        "button",

        {className: "checklist btn btn-default", onClick: function() {
          window.location.href = "feedback"
        }},

        "Submit"
      )
    )
  }
});

//#######################################################################
//                             shared state                             #
//#######################################################################
function Todos() {};

Todos.set = function(value) {
  for (var attr in value) {
    Todos[attr] = value[attr]
  }
};

// find corresponding agenda item
Todos.link = function(title) {
  var link = null;

  Agenda.index.forEach(function(item) {
    if (item.title == title) link = item.href
  });

  return link
};

//
// Blank canvas shown during bootstrapping
//
var BootStrapPage = React.createClass({
  displayName: "BootStrapPage",

  render: function() {
    return React.createElement("p", null, "")
  }
});

//
// Overall Agenda page: simple table with one row for each item in the index
//
var Index = React.createClass({
  displayName: "Index",

  render: function() {
    return React.createElement(
      "span",
      null,

      React.createElement(
        "header",
        null,
        React.createElement("h1", null, "ASF Board Agenda")
      ),

      React.createElement(
        "table",
        {className: "table-bordered"},

        React.createElement(
          "thead",
          null,
          React.createElement("th", null, "Attach"),
          React.createElement("th", null, "Title"),
          React.createElement("th", null, "Owner"),
          React.createElement("th", null, "Shepherd")
        ),

        React.createElement.apply(React, function() {
          var $_ = ["tbody", null];

          Agenda.index.forEach(function(row) {
            $_.push(React.createElement(
              "tr",
              {className: row.color},
              React.createElement("td", null, row.attach),

              React.createElement(
                "td",
                null,
                React.createElement(Link, {text: row.title, href: row.href})
              ),

              React.createElement("td", null, row.owner),

              React.createElement.apply(React, function() {
                var $_ = ["td", null];

                if (row.shepherd) {
                  $_.push(React.createElement(
                    Link,
                    {text: row.shepherd, href: "shepherd/" + row.shepherd.split(" ")[0]}
                  ))
                };

                return $_
              }())
            ))
          });

          return $_
        }())
      )
    )
  }
});

//
// A two section representation of an agenda item (typically a PMC report),
// where the two sections will show up as two columns on wide enough windows.
//
// The first section contains the item text, with a missing indicator if
// the report isn't present.  It also contains an inline copy of draft
// minutes for agenda items in section 3.
//
// The second section contains posted comments, pending comments, and
// action items associated with this agenda item.
//
// Filters may be used to highlight or hypertext link portions of the text.
//
var Report = React.createClass({
  displayName: "Report",

  getInitialState: function() {
    return {}
  },

  render: function() {
    var self = this;

    return React.createElement(
      "section",
      {className: "flexbox"},

      React.createElement.apply(React, function() {
        var $_ = ["section", null];

        if (self.props.item.warnings) {
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["ul", {className: "missing"}];

            self.props.item.warnings.forEach(function(warning) {
              $_.push(React.createElement("li", null, warning))
            });

            return $_
          }()))
        };

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["pre", {className: "report"}];

          if (self.props.item.text) {
            $_.push(React.createElement(
              Text,
              {raw: self.props.item.text, filters: self.state.filters}
            ))
          } else if (self.props.item.missing) {
            $_.push(React.createElement(
              "p",
              null,
              React.createElement("em", null, "Missing")
            ))
          } else {
            $_.push(React.createElement(
              "p",
              null,
              React.createElement("em", null, "Empty")
            ))
          };

          return $_
        }()));

        if ((self.props.item.missing || self.props.item.comments) && self.props.item.mail_list) {
          $_.push(React.createElement(
            "section",
            {className: "reminder"},
            React.createElement(Email, {item: self.props.item})
          ))
        };

        if (self.props.item.minutes) {
          $_.push(React.createElement(
            "pre",
            {className: "comment"},

            React.createElement(
              Text,
              {raw: self.props.item.minutes, filters: [hotlink]}
            )
          ))
        };

        return $_
      }()),

      React.createElement(
        "section",
        null,
        React.createElement(AdditionalInfo, {item: this.props.item}),

        React.createElement(
          "div",
          {className: "report-info"},
          React.createElement("h4", null, "Report Info"),
          React.createElement(Info, {item: this.props.item})
        )
      )
    )
  },

  // ensure componentWillReceiveProps is called on before first rendering
  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  componentWillReceiveProps: function($$props) {
    var $filters = this.state.filters;

    // determine what text filters to run
    $filters = [
      this.linebreak,
      this.todo,
      hotlink,
      this.privates,
      this.jira
    ];

    if ($$props.item.title == "Call to order") {
      $filters = [this.localtime, hotlink]
    };

    if ($$props.item.people) $filters.push(this.names);

    if ($$props.item.title == "President") {
      $filters.push(this.president_attachments)
    };

    // special processing for Minutes from previous meetings
    var date;

    if (/^3[A-Z]$/.test($$props.item.attach)) {
      $filters = [this.linkMinutes];
      date = ($$props.item.text.match(/board_minutes_(\d+_\d+_\d+)\.txt/) || [])[1];

      if (date && typeof $$props.item.minutes === 'undefined' && typeof XMLHttpRequest !== 'undefined' && Server.drafts.indexOf("board_minutes_" + date + ".txt") != -1) {
        $$props.item.minutes = "";

        retrieve("minutes/" + date, "text", function(minutes) {
          $$props.item.minutes = minutes
        })
      }
    };

    this.setState({filters: $filters})
  },

  //
  //## filters
  //
  // Highlight todos
  todo: function(text) {
    return text.replace(/TODO/g, "<span class=\"missing\">TODO</span>")
  },

  // Break long lines, treating HTML Entities (like &amp;) as one character
  linebreak: function(text) {
    // find long, breakable lines
    var regex = /(\&\w+;|.){80}.+/g;
    var result = null;
    var indicies = [];

    while (result = regex.exec(text)) {
      var line = result[0];
      if (line.replace(/\&\w+;/g, ".").length < 80) break;
      var lastspace = /^.*\s\S/.exec(line);

      if (lastspace && lastspace[0].replace(/\&\w+;/g, ".").length - 1 > 40) {
        indicies.unshift([line, result.index])
      }
    };

    // reflow each line found
    indicies.forEach(function(info) {
      var line = info[0];
      var index = info[1];
      var prefix = /^\W*/.exec(line)[0];
      var indent = new Array(prefix.length + 1).join(" ");

      var replacement = "<span class=\"hilite\" title=\"reflowed\">" + prefix + Flow.text(
        line.slice(prefix.length, line.length),
        indent
      ).replace(/\n/g, "\n" + indent) + "</span>";

      text = text.slice(0, index) + replacement + text.slice(index + line.length)
    });

    return text
  },

  // Convert start time to local time on Call to order page
  localtime: function(text) {
    var self = this;

    return text.replace(
      /\n(\s+)(Other Time Zones:.*)/,

      function(match, spaces, text) {
        var localtime = new Date(self.props.item.timestamp).toLocaleString();
        return ("\n" + spaces + "<span class='hilite'>") + ("Local Time: " + localtime + "</span>" + spaces + text)
      }
    )
  },

  // replace ids with committer links
  names: function(text) {
    var roster = "/roster/committer/";

    for (var id in this.props.item.people) {
      var person = this.props.item.people[id];

      // email addresses in 'Establish' resolutions and (ids) everywhere
      text = text.replace(
        new RegExp("(\\(|&lt;)(" + id + ")( at |@|\\))", "g"),

        function(m, pre, id, post) {
          if (person.icla) {
            return (post == ")" && person.member ? pre + "<b><a href='" + roster + id + "'>" + id + "</a></b>" + post : pre + "<a href='" + roster + id + "'>" + id + "</a>" + post)
          } else {
            return (pre + "<a class='missing' href='" + roster + "?q=" + person.name + "'>") + (id + "</a>" + post)
          }
        }
      );

      // names
      var pattern;

      if (person.icla || this.props.item.title == "Roll Call") {
        pattern = escapeRegExp(person.name).replace(/ +/g, "\\s+");

        if (typeof person.member !== 'undefined') {
          text = text.replace(new RegExp(pattern, "g"), function(match) {
            return "<a href='" + roster + id + "'>" + match + "</a>"
          })
        } else {
          text = text.replace(new RegExp(pattern, "g"), function(match) {
            return "<a href='" + roster + "?q=" + person.name + "'>" + match + "</a>"
          })
        }
      };

      // highlight potentially misspelled names
      var names, iclas, ok;

      if (person.icla && person.icla != person.name) {
        names = person.name.split(/\s+/);
        iclas = person.icla.split(/\s+/);
        ok = false;

        ok = ok || names.every(function(part) {
          return iclas.some(function(icla) {
            return icla.indexOf(part) != -1
          })
        });

        ok = ok || iclas.every(function(part) {
          return names.some(function(name) {
            return name.indexOf(part) != -1
          })
        });

        if (/^Establish/.test(this.props.item.title) && !ok) {
          text = text.replace(
            new RegExp(escapeRegExp(id + "'>" + person.name), "g"),
            ("?q=" + encodeURIComponent(person.name) + "'>") + ("<span class='commented'>" + person.name + "</span>")
          )
        } else {
          text = text.replace(
            new RegExp(escapeRegExp(person.name), "g"),
            "<a href='" + roster + id + "'>" + person.name + "</a>"
          )
        }
      };

      // put members names in bold
      if (person.member) {
        pattern = escapeRegExp(person.name).replace(/ +/g, "\\s+");

        text = text.replace(new RegExp(pattern, "g"), function(match) {
          return "<b>" + match + "</b>"
        })
      }
    };

    // treat any unmatched names in Roll Call as misspelled
    if (this.props.item.title == "Roll Call") {
      text = text.replace(
        /(\n\s{4})([A-Z].*)/g,

        function(match, space, name) {
          return space + "<a class='commented' href='" + roster + "?q=" + name + "'>" + name + "</a>"
        }
      )
    };

    // highlight any non-apache.org email addresses in establish resolutions
    if (/^Establish/.test(this.props.item.title)) {
      text = text.replace(
        /(&lt;|\()[-.\w]+@(([-\w]+\.)+\w+)(&gt;|\))/g,

        function(match) {
          return (/@apache\.org/.test(match) ? match : "<span class=\"commented\" title=\"non @apache.org email address\">" + match + "</span>")
        }
      )
    };

    // highlight mis-spelling of previous and proposed chair names
    if (this.props.item.title.substring(0, 6) == "Change" && /\(\w[-_.\w]+\)/.test(text)) {
      text = text.replace(
        /heretofore\s+appointed\s+(\w(\s|.)*?)\s+\(/,

        function(text, name) {
          return text.replace(name, "<span class='hilite'>" + name + "</span>")
        }
      );

      text = text.replace(
        /chosen\sto\s+recommend\s+(\w(\s|.)*?)\s+\(/,

        function(text, name) {
          return text.replace(name, "<span class='hilite'>" + name + "</span>")
        }
      )
    };

    return text
  },

  // link to board minutes
  linkMinutes: function(text) {
    text = text.replace(
      /board_minutes_(\d+)_\d+_\d+\.txt/g,

      function(match, year) {
        var link;

        if (Server.drafts.indexOf(match) != -1) {
          link = "https://svn.apache.org/repos/private/foundation/board/" + match
        } else {
          link = "http://apache.org/foundation/records/minutes/" + year + "/" + match
        };

        return "<a href='" + link + "'>" + match + "</a>"
      }
    );

    return text
  },

  // highlight private sections - these sections appear in the agenda but
  // will be removed when the minutes are produced (see models/minutes.rb)
  privates: function(text) {
    // inline <private>...</private> sections (and preceding spaces and tabs)
    // where the <private> and </private> are on the same line.
    var private_inline = new RegExp("([ \\t]*&lt;private&gt;.*?&lt;\\/private&gt;)", "ig");

    // block of lines (and preceding whitespace) where the first line starts
    // with <private> and the last line ends </private>.
    var private_lines = new RegExp("^([ \\t]*&lt;private&gt;(?:\\n|.)*?&lt;/private&gt;)(\\s*)$", "mig");

    // return the text with private sections marked with class private
    return text.replace(
      private_inline,
      "<span class=\"private\">$1</span>"
    ).replace(private_lines, "<div class=\"private\">$1</div>")
  },

  // expand president's attachments
  president_attachments: function(text) {
    var match = text.match(/Additionally, please see Attachments (\d) through (\d)/);
    var agenda;

    if (match) {
      agenda = Agenda.index;

      for (var i = 0; i < agenda.length; i++) {
        if (!/^\d$/.test(agenda[i].attach)) continue;

        if (agenda[i].attach >= match[1] && agenda[i].attach <= match[2]) {
          text += ("\n  " + agenda[i].attach + ". ") + ("<a " + (agenda[i].text.length == 0 ? "class=\"pres-missing\" " : "")) + ("href='" + agenda[i].href + "'>" + agenda[i].title + "</a>")
        }
      }
    };

    return text
  },

  // hotlink to JIRA issues
  jira: function(text) {
    var jira_issue = /(^|\s|\(|\[)([A-Z][A-Z0-9]+)-([1-9][0-9]*)(\.(\D|$)|[,;:\s)\]]|$)/g;

    text = text.replace(jira_issue, function(m, pre, name, issue, post) {
      if (JIRA.find(name)) {
        return (pre + "<a target='_self' ") + ("href='https://issues.apache.org/jira/browse/" + name + "-" + issue + "'>") + (name + "-" + issue + "</a>" + post)
      } else {
        return pre + name + "-" + issue + post
      }
    });

    return text
  }
});

//
// Action items.  Link to PMC reports when possible, highlight missing
// action item status updates.
//
var ActionItems = React.createClass({
  displayName: "ActionItems",

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      var first = true;
      var updates = Object.keys(Pending.status);

      $_.push(React.createElement.apply(React, function() {
        var $_ = ["section", {className: "flexbox"}];

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["pre", {className: "report"}];

          self.props.item.actions.forEach(function(action) {
            // skip actions that don't match the filter
            var match;

            if (self.props.filter) {
              match = true;

              for (var key in self.props.filter) {
                match = match && (action[key] == self.props.filter[key])
              };

              if (!match) return
            };

            // space between items and add help info on top
            if (first) {
              if (!self.props.filter && !Minutes.complete) {
                $_.push(React.createElement(
                  "p",
                  {className: "alert-info"},
                  "Click on Status to update"
                ))
              };

              first = false
            } else {
              $_.push("\n")
            };

            // action owner and text
            $_.push("* " + action.owner + ": " + action.text + "\n      ");
            var item, agenda;

            if (action.pmc && !(self.props.filter && self.props.filter.title)) {
              $_.push("[ ");

              // if there is an associated PMC and that PMC is on this month's
              // agenda, link to the current report, if reporting this month
              item = Agenda.find(action.pmc);

              if (item) {
                $_.push(React.createElement(
                  Link,
                  {className: item.color, text: action.pmc, href: item.href}
                ))
              } else if (action.pmc) {
                $_.push(React.createElement("span", {className: "blank"}, action.pmc))
              };

              // link to the original report
              if (action.date) {
                $_.push(" ");
                agenda = "board_agenda_" + action.date.replace(/\-/g, "_") + ".txt";

                if (Server.agendas.indexOf(agenda) != -1) {
                  $_.push(React.createElement(
                    "a",
                    {href: "../" + action.date + "/" + action.pmc.replace(/\W/g, "-")},
                    action.date
                  ))
                } else {
                  $_.push(React.createElement(
                    "a",

                    {href: "/board/minutes/" + action.pmc.replace(/\W/g, "_") + ("#minutes_" + action.date.replace(
                      /\-/g,
                      "_"
                    ))},

                    action.date
                  ))
                }
              };

              $_.push(" ]\n      ")
            } else if (action.date) {
              $_.push("[ " + action.date + " ]\n      ")
            };

            // launch edit dialog when there is a click on the status
            var attrs = {onClick: self.updateStatus, className: "clickable"};
            if (Minutes.complete) attrs = {};

            // copy action properties to data attributes
            for (var name in action) {
              attrs["data-" + name] = action[name]
            };

            // include pending updates
            var pending = Pending.find_status(action);
            if (pending) attrs["data-status"] = pending.status;

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["span", attrs];

              // highlight missing action item status updates
              if (pending) {
                $_.push(React.createElement("span", null, "Status: "));

                pending.status.split("\n").forEach(function(line) {
                  match = line.match(/^( *)(.*)/);
                  $_.push(React.createElement("span", null, match[1]));

                  $_.push(React.createElement(
                    "em",
                    {className: "commented"},
                    match[2] + "\n"
                  ))
                })
              } else if (action.status == "") {
                $_.push(React.createElement(
                  "span",
                  {className: "missing"},
                  "Status:"
                ));

                $_.push("\n")
              } else {
                $_.push(React.createElement(
                  Text,
                  {raw: "Status: " + action.status + "\n", filters: [hotlink]}
                ))
              };

              return $_
            }()))
          });

          if (first) {
            $_.push(React.createElement(
              "p",
              null,
              React.createElement("em", null, "Empty")
            ))
          };

          return $_
        }()));

        if (!first) {
          // Update action item (hidden form)
          $_.push(React.createElement(
            ModalDialog,
            {id: "updateStatusForm", color: "commented"},
            React.createElement("h4", null, "Update Action Item"),

            React.createElement.apply(React, function() {
              var $_ = ["p", null];

              $_.push(React.createElement(
                "span",
                null,
                self.state.owner + ": " + self.state.text
              ));

              if (self.state.pmc) {
                $_.push(" [ ");

                if (self.state.pmc) {
                  $_.push(React.createElement("span", null, " " + self.state.pmc))
                };

                if (self.state.date) {
                  $_.push(React.createElement("span", null, " " + self.state.date))
                };

                $_.push(" ]")
              };

              return $_
            }()),

            React.createElement("textarea", {
              ref: "statusText",
              label: "Status:",
              value: self.state.status,
              rows: 5,

              onChange: function(event) {
                self.setState({status: event.target.value})
              }
            }),

            React.createElement(
              "button",

              {
                className: "btn-default",
                "data-dismiss": "modal",
                disabled: self.state.disabled
              },

              "Cancel"
            ),

            React.createElement(
              "button",

              {
                className: "btn-primary",
                onClick: self.save,
                disabled: self.state.disabled || (self.state.baseline == self.state.status)
              },

              "Save"
            )
          ))
        };

        return $_
      }()));

      // Action Items Captured During the Meeting
      var captured;

      if (self.props.item.title == "Action Items") {
        captured = [];

        Minutes.actions.forEach(function(action) {
          var match;

          if (self.props.filter) {
            match = true;

            for (var key in self.props.filter) {
              match = match && (action[key] == self.props.filter[key])
            };

            if (!match) return
          };

          captured.push(action)
        });

        if (captured.length != 0) {
          $_.push(React.createElement(
            "section",
            null,

            React.createElement(
              "h3",
              null,
              "Action Items Captured During the Meeting"
            ),

            React.createElement.apply(React, function() {
              var $_ = ["pre", {className: "comment"}];

              captured.forEach(function(action) {
                // skip actions that don't match the filter
                var match;

                if (self.props.filter) {
                  match = true;

                  for (var key in self.props.filter) {
                    match = match && (action[key] == self.props.filter[key])
                  };

                  if (!match) return
                };

                $_.push("* " + action.owner + ": " + action.text.replace(
                  /\n/g,
                  "\n        "
                ) + "\n");

                $_.push("      [ ");

                if (action.item) {
                  $_.push(React.createElement(Link, {
                    className: action.item.color,
                    text: action.item.title,
                    href: action.item.href
                  }))
                };

                $_.push(" " + Agenda.title + " ]\n\n")
              });

              return $_
            }())
          ))
        }
      };

      return $_
    }())
  },

  // autofocus on action status in update action form
  componentDidMount: function() {
    var self = this;

    jQuery("#updateStatusForm").on("shown.bs.modal", function() {
      self.refs.statusText.focus()
    })
  },

  // launch update status form when status text is clicked
  updateStatus: function(event) {
    var parent = event.target.parentNode;

    // construct action from data attributes
    var action = {};

    for (var i = 0; i < parent.attributes.length; i++) {
      var attr = parent.attributes[i];

      if (attr.name.substring(0, 5) == "data-") {
        action[attr.name.slice(5, attr.name.length)] = attr.value
      }
    };

    // unindent action
    action.status = action.status.replace(/\n {14}/g, "\n");

    // set baseline to current value
    action.baseline = action.status;

    // show dialog
    jQuery("#updateStatusForm").modal("show");

    // update state
    this.setState(action)
  },

  // when save button is pushed, post update and dismiss modal when complete
  save: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      owner: this.state.owner,
      text: this.state.text,
      pmc: this.state.pmc,
      date: this.state.date,
      status: this.state.status
    };

    this.setState({disabled: true});

    post("status", data, function(pending) {
      jQuery(self.refs.updateStatusForm).modal("hide");
      self.setState({disabled: false});
      Pending.load(pending)
    })
  }
});

//
// Search component: 
//  * prompt for search 
//  * display matching paragraphs from agenda, highlighting search strings
//  * keep query string in window location URL in synch
//
var Search = React.createClass({
  displayName: "Search",

  // initialize query text based on data passed to the component
  getInitialState: function() {
    return {text: this.props.item.query || ""}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];

      // search input field
      $_.push(React.createElement(
        "div",
        {className: "search"},
        React.createElement("label", {htmlFor: "search_text"}, "Search:"),

        React.createElement("input", {
          id: "search-text",
          autoFocus: "autofocus",
          value: self.state.text,
          onInput: self.input,

          onChange: function(event) {
            self.setState({text: event.target.value})
          }
        })
      ));

      var matches, text;

      if (self.state.text.length > 2) {
        matches = false;
        text = self.state.text.toLowerCase();

        Agenda.index.forEach(function(item) {
          if (!item.text || item.text.toLowerCase().indexOf(text) == -1) return;
          matches = true;

          $_.push(React.createElement.apply(React, function() {
            var $_ = ["section", null];

            $_.push(React.createElement(
              "h4",
              null,
              React.createElement(Link, {text: item.title, href: item.href})
            ));

            // highlight matching strings in paragraph
            item.text.split(/\n\s*\n/).forEach(function(paragraph) {
              if (paragraph.toLowerCase().indexOf(text) != -1) {
                $_.push(React.createElement("pre", {
                  className: "report",

                  dangerouslySetInnerHTML: {__html: htmlEscape(paragraph).replace(
                    new RegExp("(" + text + ")", "gi"),
                    "<span class='hilite'>$1</span>"
                  )}
                }))
              }
            });

            return $_
          }()))
        });

        // if no sections were output, indicate 'no matches'
        if (!matches) {
          $_.push(React.createElement(
            "p",
            null,
            React.createElement("em", null, "No matches")
          ))
        }
      } else {
        // start producing query results when input string has three characters
        $_.push(React.createElement(
          "p",
          null,
          "Please enter at least three characters"
        ))
      };

      return $_
    }())
  },

  // update text whenever input changes
  input: function(event) {
    this.setState({text: event.target.value})
  },

  componentDidMount: function() {
    this.componentDidUpdate()
  },

  // replace history state on subsequent renderings
  componentDidUpdate: function() {
    var state = {path: "search", query: this.state.text};

    if (state.query) {
      history.replaceState(
        state,
        null,
        "search?q=" + encodeURIComponent(this.state.text)
      )
    } else {
      history.replaceState(state, null, "search")
    }
  }
});

//
// A page showing all comments present across all agenda items
// Conditionally hide comments previously marked as seen.
//
var Comments = React.createClass({
  displayName: "Comments",

  statics: {buttons: function() {
    var buttons = [];

    if (MarkSeen.undo || Agenda.index.some(function(item) {
      return item.unseen_comments.length != 0
    })) buttons.push({button: MarkSeen});

    if (Pending.seen && Object.keys(Pending.seen).length != 0) {
      buttons.push({button: ShowSeen})
    };

    return buttons
  }},

  getInitialState: function() {
    return {showseen: false}
  },

  toggleseen: function() {
    this.setState({showseen: !this.state.showseen})
  },

  showseen: function() {
    return this.state.showseen
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      var found = false;

      Agenda.index.forEach(function(item) {
        if (item.comments.length == 0) return;
        var visible = (self.state.showseen ? item.comments : item.unseen_comments);

        if (visible.length != 0) {
          found = true;

          $_.push(React.createElement.apply(React, function() {
            var $_ = ["section", null];

            $_.push(React.createElement(
              Link,
              {className: "h4 " + item.color, text: item.title, href: item.href}
            ));

            visible.forEach(function(comment) {
              $_.push(React.createElement("pre", {className: "comment"}, comment))
            });

            return $_
          }()))
        }
      });

      if (!found) {
        $_.push(React.createElement.apply(React, function() {
          var $_ = ["p", null];

          if (Object.keys(Pending.seen).length == 0) {
            $_.push(React.createElement("em", null, "No comments found"))
          } else {
            $_.push(React.createElement("em", null, "No new comments found"))
          };

          return $_
        }()))
      };

      return $_
    }())
  }
});

var Help = React.createClass({
  displayName: "Help",

  render: function() {
    var self = this;

    return React.createElement(
      "span",
      null,
      React.createElement("h3", null, "Keyboard shortcuts"),

      React.createElement(
        "dl",
        {className: "dl-horizontal"},
        React.createElement("dt", null, "left arrow"),
        React.createElement("dd", null, "previous page"),
        React.createElement("dt", null, "right arrow"),
        React.createElement("dd", null, "next page"),
        React.createElement("dt", null, "enter"),

        React.createElement(
          "dd",
          null,
          "On Shepherd and Queue pages, go to the first report listed"
        ),

        React.createElement("dt", null, "C"),
        React.createElement("dd", null, "Scroll to comment section (if any)"),
        React.createElement("dt", null, "I"),
        React.createElement("dd", null, "Toggle Info dropdown"),
        React.createElement("dt", null, "N"),
        React.createElement("dd", null, "Toggle Navigation dropdown"),
        React.createElement("dt", null, "A"),

        React.createElement(
          "dd",
          null,
          "Navigate to the overall agenda page"
        ),

        React.createElement("dt", null, "F"),
        React.createElement("dd", null, "Show flagged items"),
        React.createElement("dt", null, "M"),
        React.createElement("dd", null, "Show missing items"),
        React.createElement("dt", null, "Q"),
        React.createElement("dd", null, "Show queued approvals/comments"),
        React.createElement("dt", null, "S"),

        React.createElement(
          "dd",
          null,
          "Show shepherded items (and action items)"
        ),

        React.createElement("dt", null, "X"),

        React.createElement(
          "dd",
          null,
          "Set the topic (a.k.a. mark the spot)"
        ),

        React.createElement("dt", null, "?"),
        React.createElement("dd", null, "Help (this page)")
      ),

      React.createElement("h3", null, "Color Legend"),

      React.createElement(
        "ul",
        null,

        React.createElement(
          "li",
          {className: "missing"},
          "Report missing, rejected, or has formatting errors"
        ),

        React.createElement(
          "li",
          {className: "available"},
          "Report present, not eligible for pre-reviews"
        ),

        React.createElement(
          "li",
          {className: "ready"},
          "Report present, ready for (more) review(s)"
        ),

        React.createElement(
          "li",
          {className: "reviewed"},
          "Report has sufficient pre-approvals"
        ),

        React.createElement(
          "li",
          {className: "commented"},
          "Report has been flagged for discussion"
        )
      ),

      React.createElement("h3", null, "Change Role"),

      React.createElement.apply(React, function() {
        var $_ = ["form", {id: "role"}];

        ["Secretary", "Director", "Guest"].forEach(function(role) {
          $_.push(React.createElement(
            "div",
            null,

            React.createElement("input", {
              type: "radio",
              name: "role",
              value: role.toLowerCase(),
              checked: role.toLowerCase() == Server.role,
              onChange: self.setRole
            }),

            role
          ))
        });

        return $_
      }())
    )
  },

  setRole: function(event) {
    Server.role = event.target.value;
    Main.refresh()
  }
});

//
// A page showing all queued approvals and comments, as well as items
// that are ready for review.
//
var Shepherd = React.createClass({
  displayName: "Shepherd",

  getInitialState: function() {
    return {disabled: false, followup: []}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      var shepherd = self.props.item.shepherd.toLowerCase();
      var actions = Agenda.find("Action-Items");

      if (actions.actions.some(function(action) {
        return action.owner == self.props.item.shepherd
      })) {
        $_.push(React.createElement("h2", null, "Action Items"));

        $_.push(React.createElement(
          ActionItems,
          {item: actions, filter: {owner: self.props.item.shepherd}}
        ))
      };

      $_.push(React.createElement("h2", null, "Committee Reports"));

      // list agenda items associated with this shepherd
      Agenda.index.forEach(function(item) {
        var mine;

        if (item.shepherd && item.shepherd.toLowerCase().substring(
          0,
          shepherd.length
        ) == shepherd) {
          $_.push(React.createElement(Link, {
            className: "h3 " + item.color,
            text: item.title,
            href: "shepherd/queue/" + item.href
          }));

          $_.push(React.createElement(
            AdditionalInfo,
            {item: item, prefix: true}
          ));

          // flag action
          if (item.missing || item.comments.length != 0) {
            if (/^[A-Z]+$/.test(item.attach)) {
              mine = (shepherd == Server.firstname ? "btn-primary" : "btn-link");

              $_.push(React.createElement(
                "div",
                {className: "shepherd"},

                React.createElement(
                  "button",

                  {
                    className: "btn " + (mine || ""),
                    "data-attach": item.attach,
                    onClick: self.click,
                    disabled: self.state.disabled
                  },

                  (item.flagged ? "unflag" : "flag")
                ),

                React.createElement(Email, {item: item})
              ))
            }
          }
        }
      });

      // list feedback items that may need to be followed up
      var followup = [];

      for (var title in self.state.followup) {
        if (self.state.followup[title].count != 1) continue;
        if (self.state.followup[title].shepherd != self.props.item.shepherd) continue;

        if (Agenda.index.some(function(item) {
          return item.title == title
        })) continue;

        self.state.followup[title].title = title;
        followup.push(self.state.followup[title])
      };

      if (followup.length != 0) {
        $_.push(React.createElement(
          "h2",
          null,
          "Feedback that may require followup"
        ));

        followup.forEach(function(followup) {
          var link = followup.title.replace(/[^a-zA-Z0-9]+/g, "-");

          $_.push(React.createElement(
            "a",

            {
              className: "h3 ready",
              href: "../" + self.state.prior_date + "/" + link
            },

            followup.title
          ));

          splitComments(followup.comments).forEach(function(comment) {
            $_.push(React.createElement("pre", {className: "comment"}, comment))
          })
        })
      };

      return $_
    }())
  },

  // Fetch followup items
  componentDidMount: function() {
    var self = this;

    // if cached, reuse
    if (Shepherd.followup) {
      this.setState({followup: Shepherd.followup});
      return
    };

    // determine date of previous meeting
    var prior_agenda = Server.agendas[Server.agendas.length - 2];
    if (!prior_agenda) return;

    var $prior_date = (prior_agenda.match(/\d+_\d+_\d+/) || [])[0].replace(
      /_/g,
      "-"
    );

    retrieve(
      "../" + $prior_date + "/followup.json",
      "json",

      function(followup) {
        Shepherd.followup = followup;
        self.setState({followup: followup})
      }
    );

    this.setState({prior_date: $prior_date})
  },

  click: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      initials: Server.initials,
      attach: event.target.getAttribute("data-attach"),
      request: event.target.textContent
    };

    this.setState({disabled: true});

    post("approve", data, function(pending) {
      self.setState({disabled: false});
      Pending.load(pending)
    })
  }
});

//
// A page showing all queued approvals and comments, as well as items
// that are ready for review.
//
var Queue = React.createClass({
  displayName: "Queue",

  statics: {buttons: function() {
    var buttons = [{button: Refresh}];
    if (Pending.count > 0) buttons.push({form: Commit});
    return buttons
  }},

  getInitialState: function() {
    return {}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["div", {className: "col-xs-12"}];

      if (Server.role == "director") {
        // Approvals
        $_.push(React.createElement("h4", null, "Approvals"));

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["p", {className: "col-xs-12"}];

          self.state.approvals.forEach(function(item, index) {
            if (index > 0) $_.push(React.createElement("span", null, ", "));

            $_.push(React.createElement(
              Link,
              {text: item.title, href: "queue/" + item.href}
            ))
          });

          if (self.state.approvals.length == 0) {
            $_.push(React.createElement("em", null, "None."))
          };

          return $_
        }()));

        // Unapproved
        ["Unapprovals", "Flagged", "Unflagged"].forEach(function(section) {
          var list = self.state[section.toLowerCase()];

          if (list.length != 0) {
            $_.push(React.createElement("h4", null, section));

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["p", {className: "col-xs-12"}];

              list.forEach(function(item, index) {
                if (index > 0) $_.push(React.createElement("span", null, ", "));

                $_.push(React.createElement(
                  Link,
                  {text: item.title, href: item.href}
                ))
              });

              return $_
            }()))
          }
        })
      };

      // Comments
      $_.push(React.createElement("h4", null, "Comments"));

      if (self.state.comments.length == 0) {
        $_.push(React.createElement(
          "p",
          {className: "col-xs-12"},
          React.createElement("em", null, "None.")
        ))
      } else {
        $_.push(React.createElement.apply(React, function() {
          var $_ = ["dl", {className: "dl-horizontal"}];

          self.state.comments.forEach(function(item) {
            $_.push(React.createElement(
              "dt",
              null,
              React.createElement(Link, {text: item.title, href: item.href})
            ));

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["dd", null];

              item.pending.split("\n\n").forEach(function(paragraph) {
                $_.push(React.createElement("p", null, paragraph))
              });

              return $_
            }()))
          });

          return $_
        }()))
      };

      // Action Item Status updates
      if (Pending.status.length != 0) {
        $_.push(React.createElement("h4", null, "Action Items"));

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          Pending.status.forEach(function(item) {
            var text = item.text;

            if (item.pmc || item.date) {
              text += " [";
              if (item.pmc) text += " " + item.pmc;
              if (item.date) text += " " + item.date;
              text += " ]"
            };

            $_.push(React.createElement("li", null, text))
          });

          return $_
        }()))
      };

      // Ready
      if (Server.role == "director" && self.state.ready.length != 0) {
        $_.push(React.createElement(
          "div",
          {className: "row col-xs-12"},
          React.createElement("hr")
        ));

        $_.push(React.createElement("h4", null, "Ready for review"));

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["p", {className: "col-xs-12"}];

          self.state.ready.forEach(function(item, index) {
            if (index > 0) $_.push(React.createElement("span", null, ", "));

            $_.push(React.createElement(Link, {
              className: (index == 0 ? "default" : null),
              text: item.title,
              href: "queue/" + item.href
            }))
          });

          return $_
        }()))
      };

      return $_
    }())
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // determine approvals, rejected, comments, and ready
  componentWillReceiveProps: function($$props) {
    var $approvals = [];
    var $unapprovals = [];
    var $flagged = [];
    var $unflagged = [];
    var $comments = [];
    var $ready = [];

    Agenda.index.forEach(function(item) {
      if (Pending.comments[item.attach]) $comments.push(item);
      var action = false;

      if (Pending.approved.indexOf(item.attach) != -1) {
        $approvals.push(item);
        action = true
      };

      if (Pending.unapproved.indexOf(item.attach) != -1) {
        $unapprovals.push(item);
        action = true
      };

      if (Pending.flagged.indexOf(item.attach) != -1) {
        $flagged.push(item);
        action = true
      };

      if (Pending.unflagged.indexOf(item.attach) != -1) {
        $unflagged.push(item);
        action = true
      };

      if (!action && item.ready_for_review(Server.initials)) $ready.push(item)
    });

    this.setState({
      unflagged: $unflagged,
      unapprovals: $unapprovals,
      ready: $ready,
      flagged: $flagged,
      comments: $comments,
      approvals: $approvals
    })
  }
});

//
// A page showing all flagged reports
//
var Flagged = React.createClass({
  displayName: "Flagged",

  render: function() {
    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      var first = true;

      Agenda.index.forEach(function(item) {
        if (item.flagged_by || Pending.flagged.indexOf(item.attach) != -1) {
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["h3", {className: item.color}];

            $_.push(React.createElement(Link, {
              className: (first ? "default" : null),
              text: item.title,
              href: "flagged/" + item.href
            }));

            first = false;

            $_.push(React.createElement(
              "span",
              {className: "owner"},
              " [" + item.owner + " / " + item.shepherd + "]"
            ));

            var flagged_by = Server.directors[item.flagged_by] || item.flagged_by;

            $_.push(React.createElement(
              "span",
              {className: "owner"},
              " flagged by: " + flagged_by
            ));

            return $_
          }()));

          $_.push(React.createElement(
            AdditionalInfo,
            {item: item, prefix: true}
          ))
        }
      });

      if (first) $_.push(React.createElement("em", {className: "comment"}, "None"));
      return $_
    }())
  }
});

//
// A page showing all flagged reports
//
var Missing = React.createClass({
  displayName: "Missing",

  getInitialState: function() {
    return {checked: {}}
  },

  componentDidMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // update check marks based on current Index
  componentWillReceiveProps: function($$props) {
    var self = this;

    Agenda.index.forEach(function(item) {
      if (typeof self.state.checked[item.title] === 'undefined') {
        self.state.checked[item.title] = true
      }
    })
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      var first = true;

      Agenda.index.forEach(function(item) {
        if (item.missing) {
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["h3", {className: item.color}];

            if (/^[A-Z]+/.test(item.attach)) {
              $_.push(React.createElement("input", {
                type: "checkbox",
                name: "selected",
                value: item.title,
                checked: self.state.checked[item.title],

                onChange: function() {
                  self.state.checked[item.title] = !self.state.checked[item.title];
                  self.forceUpdate()
                }
              }))
            };

            $_.push(React.createElement(Link, {
              className: (first ? "default" : null),
              text: item.title,
              href: "flagged/" + item.href
            }));

            first = false;

            $_.push(React.createElement(
              "span",
              {className: "owner"},
              " [" + item.owner + " / " + item.shepherd + "]"
            ));

            var flagged_by;

            if (item.flagged_by) {
              flagged_by = Server.directors[item.flagged_by] || item.flagged_by;

              $_.push(React.createElement(
                "span",
                {className: "owner"},
                " flagged by: " + flagged_by
              ))
            };

            return $_
          }()));

          $_.push(React.createElement(
            AdditionalInfo,
            {item: item, prefix: true}
          ))
        }
      });

      if (first) $_.push(React.createElement("em", {className: "comment"}, "None"));
      return $_
    }())
  }
});

//
// Overall Agenda page: simple table with one row for each item in the index
//
var Backchannel = React.createClass({
  displayName: "Backchannel",
  statics: {buttons: function() {return [{button: Message}]}},

  // render a list of messages
  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];

      $_.push(React.createElement(
        "header",
        null,
        React.createElement("h1", null, "Agenda Backchannel")
      ));

      // convert date into a localized string
      var datefmt = function(timestamp) {
        return new Date(timestamp).toLocaleDateString(
          {},
          {month: "short", day: "numeric", year: "numeric"}
        )
      };

      var i;

      if (Chat.log.length == 0) {
        if (Chat.backlog_fetched) {
          $_.push(React.createElement("em", null, "No messages found."))
        } else {
          $_.push(React.createElement("em", null, "Loading messages"))
        }
      } else {
        i = 0;

        // group messages by date
        while (i < Chat.log.length) {
          var date = datefmt(Chat.log[i].timestamp);

          if (i != 0 || date != datefmt(new Date().valueOf())) {
            $_.push(React.createElement("h5", {className: "chatlog"}, date))
          };

          // group of messages that share the same (local) date
          $_.push(React.createElement.apply(React, function() {
            var $_ = ["dl", {className: "chatlog"}];

            while (i < Chat.log.length) {
              var message = Chat.log[i];
              if (date != datefmt(message.timestamp)) break;

              $_.push(React.createElement(
                "dt",

                {
                  className: message.type,
                  key: "t" + message.timestamp,
                  title: new Date(message.timestamp).toLocaleTimeString()
                },

                message.user
              ));

              $_.push(React.createElement.apply(React, function() {
                var $_ = [
                  "dd",
                  {className: message.type, key: "d" + message.timestamp}
                ];

                if (message.link) {
                  $_.push(React.createElement(
                    Link,
                    {text: message.text, href: message.link}
                  ))
                } else {
                  $_.push(React.createElement(
                    Text,
                    {raw: message.text, filters: [hotlink, self.mention]}
                  ))
                };

                return $_
              }()));

              i++
            };

            return $_
          }()))
        }
      };

      return $_
    }())
  },

  // highlight mentions of my id
  mention: function(text) {
    return text.replace(
      new RegExp("<.*?>|\\b(" + Server.userid + ")\\b", "g"),

      function(match) {
        return (match[0] == "<" ? match : "<span class=mention>" + match + "</span>")
      }
    )
  },

  // on initial display, fetch backlog
  componentDidMount: function() {
    Main.scrollTo = -1;
    Chat.fetch_backlog()
  },

  // if we are at the bottom of the page, keep it that way
  componentWillUpdate: function() {
    if (window.pageYOffset + window.innerHeight >= document.documentElement.scrollHeight) {
      Main.scrollTo = -1
    } else {
      Main.scrollTo = null
    }
  }
});

//
// Secretary Roll Call update form
var RollCall = React.createClass({
  displayName: "RollCall",

  getInitialState: function() {
    this.state = {};
    RollCall.lockFocus = false;
    this.state.guest = "";
    return this.state
  },

  render: function() {
    var self = this;

    return React.createElement(
      "section",
      {className: "flexbox"},

      React.createElement(
        "section",
        {id: "rollcall"},
        React.createElement("h3", null, "Directors"),

        React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          self.state.people.forEach(function(person) {
            if (person.role == "director") {
              $_.push(React.createElement(Attendee, {person: person}))
            }
          });

          return $_
        }()),

        React.createElement("h3", null, "Executive Officers"),

        React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          self.state.people.forEach(function(person) {
            if (person.role == "officer") {
              $_.push(React.createElement(Attendee, {person: person}))
            }
          });

          return $_
        }()),

        React.createElement("h3", null, "Guests"),

        React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          self.state.people.forEach(function(person) {
            if (person.role == "guest") {
              $_.push(React.createElement(Attendee, {person: person}))
            }
          });

          // walk-on guest support
          $_.push(React.createElement(
            "li",
            null,

            React.createElement("input", {
              className: "walkon",
              value: self.state.guest,
              disabled: self.state.disabled,

              onFocus: function() {
                RollCall.lockFocus = true
              },

              onBlur: function() {
                RollCall.lockFocus = false
              },

              onChange: function(event) {
                self.setState({guest: event.target.value})
              }
            })
          ));

          var guest, found;

          if (self.state.guest.length >= 3) {
            guest = self.state.guest.toLowerCase().split(" ");
            found = false;

            Server.committers.forEach(function(person) {
              if (guest.every(function(part) {
                return person.id.indexOf(part) != -1 || person.name.toLowerCase().indexOf(part) != -1
              }) && !self.state.people.some(function(registered) {
                return registered.id == person.id
              })) {
                $_.push(React.createElement(Attendee, {person: person, walkon: true}));
                found = true
              }
            });

            // non committer
            if (!found) {
              $_.push(React.createElement(
                Attendee,
                {person: {name: self.state.guest}, walkon: true}
              ))
            }
          };

          return $_
        }())
      ),

      React.createElement.apply(React, function() {
        var $_ = ["section", null];
        var minutes = Minutes.get(self.props.item.title);

        if (minutes) {
          $_.push(React.createElement("h3", null, "Minutes"));
          $_.push(React.createElement("pre", {className: "comment"}, minutes))
        };

        return $_
      }())
    )
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // collect a sorted list of people
  componentWillReceiveProps: function($$props) {
    var people = [];

    // start with those listed in the agenda
    for (var id in $$props.item.people) {
      var person = $$props.item.people[id];
      person.id = id;
      people.push(person)
    };

    // add remaining attendees
    var attendees = Minutes.attendees;

    if (attendees) {
      for (var name in attendees) {
        var person;

        if (!people.some(function(person) {
          return person.name == name
        })) {
          person = attendees[name];
          person.name = name;
          person.role = "guest";
          people.push(person)
        }
      }
    };

    // sort list
    this.setState({people: people.sort(function(person1, person2) {
      return (person1.sortName > person2.sortName ? 1 : -1)
    })})
  },

  // clear guest
  clear_guest: function() {
    this.setState({guest: ""})
  },

  // client side initialization on first rendering
  componentDidMount: function() {
    var self = this;

    if (Server.committers) {
      this.setState({disabled: false})
    } else {
      this.setState({disabled: true});

      retrieve("committers", "json", function(committers) {
        Server.committers = committers || [];
        self.setState({disabled: false})
      })
    };

    // export clear method
    RollCall.clear_guest = this.clear_guest
  },

  // scroll walkon input field towards the center of the screen
  componentDidUpdate: function() {
    var walkon, offset;

    if (RollCall.lockFocus && this.state.guest.length >= 3) {
      walkon = document.getElementsByClassName("walkon")[0];
      offset = walkon.offsetTop + walkon.offsetHeight / 2 - window.innerHeight / 2;
      jQuery("html, body").animate({scrollTop: offset}, "slow")
    }
  }
});

//
// An individual attendee (Director, Executive Officer, or Guest)
//
var Attendee = React.createClass({
  displayName: "Attendee",

  getInitialState: function() {
    return {base: ""}
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // whenever person changes, reflect current status
  componentWillReceiveProps: function($$props) {
    var status = Minutes.attendees[$$props.person.name];

    if (status) {
      this.setState({
        checked: status.present,
        notes: (status.notes ? status.notes.replace(" - ", "") : "")
      })
    } else {
      this.setState({checked: "", notes: ""})
    }
  },

  // render a checkbox, a hypertexted link of the attendee's name to the
  // roster page for the committer, and notes in both editable and non-editable
  // forms.  CSS controls which version of the notes is actually displayed.
  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["li", {onMouseOver: self.focus}];

      $_.push(React.createElement(
        "input",
        {type: "checkbox", checked: self.state.checked, onChange: self.click}
      ));

      var roster = "/roster/committer/";

      if (self.props.person.id) {
        $_.push(React.createElement(
          "a",

          {
            href: roster + self.props.person.id,
            style: {fontWeight: (self.props.person.member ? "bold" : "normal")}
          },

          self.props.person.name
        ))
      } else {
        $_.push(React.createElement(
          "a",
          {className: "hilite", href: roster + "?q=" + self.props.person.name},
          self.props.person.name
        ))
      };

      if (!self.props.walkon && !self.state.checked && self.props.person.role != "guest" && !self.props.person.attending) {
        if (!self.state.notes) {
          $_.push(React.createElement("span", null, " (expected to be absent)"))
        }
      };

      if (!self.props.walkon) {
        $_.push(React.createElement("label"));

        $_.push(React.createElement("input", {
          type: "text",
          value: self.state.notes,
          onBlur: self.blur,
          disabled: self.state.disabled,

          onChange: function(event) {
            self.setState({notes: event.target.value})
          }
        }));

        if (self.state.notes) {
          $_.push(React.createElement("span", null, " - " + self.state.notes))
        }
      };

      return $_
    }())
  },

  // when moving cursor over a list item, focus on the input field
  focus: function(event) {
    if (!RollCall.lockFocus) {
      event.target.parentNode.querySelector("input[type=text]").focus()
    }
  },

  // initialize pending update status
  componentDidMount: function() {
    this.pending = false
  },

  // when checkbox is clicked, set pending update status
  click: function(event) {
    this.setState({checked: event.target.checked});
    this.pending = true
  },

  // when leaving a list item, set pending update status if value changed
  blur: function() {
    if (this.state.base != this.state.notes) {
      this.pending = true;
      this.setState({base: this.state.notes})
    }
  },

  // after display is updated, send any pending updates to the server
  componentDidUpdate: function() {
    var self = this;
    if (!this.pending) return;

    var data = {
      agenda: Agenda.file,
      action: "attendance",
      name: this.props.person.name,
      id: this.props.person.id,
      present: this.state.checked,
      notes: this.state.notes
    };

    this.setState({disabled: true});

    post("minute", data, function(minutes) {
      Minutes.load(minutes);
      if (self.props.walkon) RollCall.clear_guest();
      self.setState({disabled: false})
    });

    this.pending = false
  }
});

//
// Action items.  Link to PMC reports when possible, highlight missing
// action item status updates.
//
var SelectActions = React.createClass({
  displayName: "SelectActions",
  statics: {buttons: function() {return [{button: PostActions}]}},

  getInitialState: function() {
    this.state = {};
    SelectActions.list = [];
    this.state.names = [];
    return this.state
  },

  render: function() {
    var self = this;

    return React.createElement(
      "span",
      null,
      React.createElement("h3", null, "Post Action Items"),

      React.createElement(
        "p",
        {className: "alert-info"},
        "Action Items have yet to be posted. " + "Unselect the ones below that have been completed. " + "Click on the \"post actions\" button when done."
      ),

      React.createElement.apply(React, function() {
        var $_ = ["pre", {className: "report"}];

        SelectActions.list.forEach(function(action) {
          $_.push(React.createElement(
            CandidateAction,
            {action: action, names: self.state.names}
          ))
        });

        return $_
      }())
    )
  },

  componentDidMount: function() {
    var self = this;

    retrieve("potential-actions", "json", function(response) {
      if (response) {
        SelectActions.list = response.actions;
        self.setState({names: response.names})
      }
    })
  }
});

var CandidateAction = React.createClass({
  displayName: "CandidateAction",

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];

      $_.push(React.createElement("input", {
        type: "checkbox",
        checked: !self.props.action.complete,

        onChange: function() {
          self.props.action.complete = !self.props.action.complete;
          self.forceUpdate()
        }
      }));

      $_.push(React.createElement("span", null, " "));
      $_.push(React.createElement("span", null, self.props.action.owner));
      $_.push(React.createElement("span", null, ": "));
      $_.push(React.createElement("span", null, self.props.action.text));

      $_.push(React.createElement(
        "span",
        null,
        "\n      [ " + self.props.action.pmc + " " + self.props.action.date + " ]\n      "
      ));

      if (self.props.action.status) {
        $_.push(React.createElement(Text, {
          raw: "Status: " + self.props.action.status + "\n",
          filters: [hotlink]
        }))
      };

      $_.push(React.createElement("span", null, "\n"));
      return $_
    }())
  }
});

//
// A page showing status of caches and service workers
//
var CacheStatus = React.createClass({
  displayName: "CacheStatus",

  statics: {buttons: function() {
    return [{button: ClearCache}, {button: UnregisterWorker}]
  }},

  getInitialState: function() {
    return {cache: [], registrations: []}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      $_.push(React.createElement("h2", null, "Status"));

      if (typeof navigator !== 'undefined' && "serviceWorker" in navigator) {
        $_.push(React.createElement(
          "p",
          null,
          "Service workers ARE supported by this browser"
        ))
      } else {
        $_.push(React.createElement(
          "p",
          null,
          "Service workers are NOT supported by this browser"
        ))
      };

      $_.push(React.createElement("h2", null, "Cache"));

      if (self.state.cache.length == 0) {
        $_.push(React.createElement("p", null, "empty"))
      } else {
        $_.push(React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          self.state.cache.forEach(function(item) {
            var basename = item.split("/").pop();
            if (basename == "") basename = "index.html";

            if (basename == "bootstrap.html") {
              basename = item.split("/")[item.split("/").length - 2] + ".html"
            };

            $_.push(React.createElement(
              "li",
              null,
              React.createElement(Link, {text: item, href: "cache/" + basename})
            ))
          });

          return $_
        }()))
      };

      $_.push(React.createElement("h2", null, "Service Workers"));

      if (self.state.registrations.length == 0) {
        $_.push(React.createElement("p", null, "none found"))
      } else {
        $_.push(React.createElement(
          "table",
          {className: "table"},

          React.createElement(
            "thead",
            null,
            React.createElement("th", null, "Scope"),
            React.createElement("th", null, "Status")
          ),

          React.createElement.apply(React, function() {
            var $_ = ["tbody", null];

            self.state.registrations.forEach(function(registration) {
              $_.push(React.createElement(
                "tr",
                null,
                React.createElement("td", null, registration.scope),

                React.createElement.apply(React, function() {
                  var $_ = ["td", null];

                  if (registration.installing) {
                    $_.push(React.createElement("span", null, "installing"))
                  } else if (registration.waiting) {
                    $_.push(React.createElement("span", null, "waiting"))
                  } else if (registration.active) {
                    $_.push(React.createElement("span", null, "active"))
                  } else {
                    $_.push(React.createElement("span", null, "unknown"))
                  };

                  return $_
                }())
              ))
            });

            return $_
          }())
        ))
      };

      return $_
    }())
  },

  componentDidMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // update caches
  componentWillReceiveProps: function($$props) {
    var self = this;

    if (typeof caches !== 'undefined') {
      caches.open("board/agenda").then(function(cache) {
        cache.matchAll().then(function(responses) {
          cache = responses.map(function(response) {
            return response.url
          });

          cache.sort();
          self.setState({cache: cache})
        })
      });

      navigator.serviceWorker.getRegistrations().then(function(registrations) {
        self.setState({registrations: registrations})
      })
    }
  }
});

//
// A button that clear the cache
//
var ClearCache = React.createClass({
  displayName: "ClearCache",

  getInitialState: function() {
    return {disabled: true}
  },

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled
      },

      "Clear Cache"
    )
  },

  componentDidMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // enable button if there is anything in the cache
  componentWillReceiveProps: function($$props) {
    var self = this;

    if (typeof caches !== 'undefined') {
      caches.open("board/agenda").then(function(cache) {
        cache.matchAll().then(function(responses) {
          self.setState({disabled: responses.length == 0})
        })
      })
    }
  },

  click: function(event) {
    if (typeof caches !== 'undefined') {
      caches.delete("board/agenda").then(function(status) {
        Main.refresh()
      })
    }
  }
});

//
// A button that removes the service worker.  Sadly, it doesn't seem to have
// any affect on the list of registrations that is dynamically returned.
//
var UnregisterWorker = React.createClass({
  displayName: "UnregisterWorker",

  render: function() {
    return React.createElement(
      "button",
      {className: "btn btn-primary", onClick: this.click},
      "Unregister ServiceWorker"
    )
  },

  click: function(event) {
    if (typeof caches !== 'undefined') {
      navigator.serviceWorker.getRegistrations().then(function(registrations) {
        var base = new URL("..", document.getElementsByTagName("base")[0].href).href;

        registrations.forEach(function(registration) {
          if (registration.scope == base) {
            registration.unregister().then(function(status) {
              Main.refresh()
            })
          }
        })
      })
    }
  }
});

//
// Individual Cache page
//
var CachePage = React.createClass({
  displayName: "CachePage",

  getInitialState: function() {
    return {response: {}, text: ""}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];
      $_.push(React.createElement("h2", null, self.state.response.url));

      $_.push(React.createElement(
        "p",
        null,
        self.state.response.status + " " + self.state.response.statusText
      ));

      var keys, iterator, entry;

      if (self.state.response.headers) {
        // avoid buggy @response.headers.keys()
        keys = [];
        iterator = self.state.response.headers.entries();
        entry = iterator.next();

        while (!entry.done) {
          if (entry.value[0] != "status") keys.push(entry.value[0]);
          entry = iterator.next()
        };

        keys.sort();

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          keys.forEach(function(key) {
            $_.push(React.createElement(
              "li",
              null,
              key + ": " + self.state.response.headers.get(key)
            ))
          });

          return $_
        }()))
      };

      $_.push(React.createElement("pre", null, self.state.text));
      return $_
    }())
  },

  // update on first update
  componentDidMount: function() {
    var self = this;
    var basename;

    if (typeof caches !== 'undefined') {
      basename = location.href.split("/").pop();
      if (basename == "index.html") basename = "";
      if (/^\d+-\d+-\d+\.html$/.test(basename)) basename = "bootstrap.html";

      caches.open("board/agenda").then(function(cache) {
        cache.matchAll().then(function(responses) {
          responses.forEach(function(response) {
            if (response.url.split("/").pop() == basename) {
              self.setState({response: response});

              response.text().then(function(text) {
                self.setState({text: text})
              })
            }
          })
        })
      })
    }
  }
});

//
// FY22 budget worksheet
//
var FY22 = React.createClass({
  displayName: "FY22",

  getInitialState: function() {
    this.state = {budget: (Minutes.started && Minutes.get("budget")) || {
      donations: 110,
      sponsorship: 1000,
      infrastructure: 868,
      publicity: 352,
      brandManagement: 141,
      conferences: 12,
      travelAssistance: 79,
      treasury: 51,
      fundraising: 23,
      generalAndAdministrative: 139
    }};

    if (Server.role == "secretary" || !Minutes.started) {
      this.state.disabled = false
    } else {
      this.state.disabled = true
    };

    this.recalc();
    return this.state
  },

  render: function() {
    return React.createElement(
      "span",
      null,

      React.createElement(
        "style",
        null,
        "\n" + "      .table thead tr th {text-align: right}\n" + "      .table tbody tr td {text-align: left}\n" + "      .table tbody tr td.num {text-align: right}\n" + "      .table tbody tr td.indented {padding-left: 2em}\n" + "      .table tbody tr td input {align: right; text-align: right}\n" + "      .table tbody tr td a {color: blue; text-decoration:underline}\n" + "    "
      ),

      React.createElement(
        "p",
        null,
        "Instructions: change any input field and press the tab key to see " + "new results. Try to make FY22 Budget Net non-negative."
      ),

      React.createElement(
        "table",
        {className: "table table-sm table-striped"},

        React.createElement("thead", null, React.createElement(
          "tr",
          null,
          React.createElement("th"),
          React.createElement("th", null, "FY17"),
          React.createElement("th", null, "Min FY22"),
          React.createElement("th", null, "FY22"),
          React.createElement("th", null, "Max FY22"),
          React.createElement("th", null, "FY22 Budget")
        )),

        React.createElement(
          "tbody",
          null,

          React.createElement(
            "tr",
            null,
            React.createElement("td", {colSpan: 6}, "Income")
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/sxYI"},
                "Total Public Donations"
              )
            ),

            React.createElement("td", {className: "num"}, 89),
            React.createElement("td", {className: "num"}, 90),
            React.createElement("td", {className: "num"}, 110),
            React.createElement("td", {className: "num"}, 135),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "donations",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.donations.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/sxYI"},
                "Total Sponsorship"
              )
            ),

            React.createElement("td", {className: "num"}, 968),
            React.createElement("td", {className: "num"}, 900),

            React.createElement(
              "td",
              {className: "num"},
              (1000).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (1100).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "sponsorship",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.sponsorship.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {className: "indented"}, "Total Programs"),
            React.createElement("td", {className: "num"}, 28),
            React.createElement("td", {className: "num"}, 28),
            React.createElement("td", {className: "num"}, 28),
            React.createElement("td", {className: "num"}, 28),
            React.createElement("td", {className: "num"}, 28)
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {className: "indented"}, "Interest Income"),
            React.createElement("td", {className: "num"}, 4),
            React.createElement("td", {className: "num"}, 4),
            React.createElement("td", {className: "num"}, 4),
            React.createElement("td", {className: "num"}, 4),
            React.createElement("td", {className: "num"}, 4)
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----")
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {className: "indented"}, "Total Income"),

            React.createElement(
              "td",
              {className: "num"},
              (1089).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (1022).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (1142).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (1267).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num", id: "income"},
              this.state.budget.income.toLocaleString()
            )
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {colSpan: 6})
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {colSpan: 6}, "Expense")
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/Rlse"},
                "Infrastructure"
              )
            ),

            React.createElement("td", {className: "num"}, 723),
            React.createElement("td", {className: "num"}, 868),
            React.createElement("td", {className: "num"}, 868),
            React.createElement("td", {className: "num"}, 868),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "infrastructure",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.infrastructure.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},
              "Program Expenses"
            ),

            React.createElement("td", {className: "num"}, 27),
            React.createElement("td", {className: "num"}, 27),
            React.createElement("td", {className: "num"}, 27),
            React.createElement("td", {className: "num"}, 27),
            React.createElement("td", {className: "num"}, 27)
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/lv76"},
                "Publicity"
              )
            ),

            React.createElement("td", {className: "num"}, 141),
            React.createElement("td", {className: "num"}, 273),
            React.createElement("td", {className: "num"}, 352),
            React.createElement("td", {className: "num"}, 540),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "publicity",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.publicity.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/gXdY"},
                "Brand Management"
              )
            ),

            React.createElement("td", {className: "num"}, 84),
            React.createElement("td", {className: "num"}, 92),
            React.createElement("td", {className: "num"}, 141),
            React.createElement("td", {className: "num"}, 218),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "brandManagement",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.brandManagement.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {className: "indented"}, "Conferences"),
            React.createElement("td", {className: "num"}, 12),
            React.createElement("td", {className: "num"}, 12),
            React.createElement("td", {className: "num"}, 12),
            React.createElement("td", {className: "num"}, 12),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "conferences",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.conferences.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/4LdI"},
                "Travel Assistance"
              )
            ),

            React.createElement("td", {className: "num"}, 62),
            React.createElement("td", {className: "num"}, 0),
            React.createElement("td", {className: "num"}, 79),
            React.createElement("td", {className: "num"}, 150),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "travelAssistance",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.travelAssistance.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/EGiC"},
                "Treasury"
              )
            ),

            React.createElement("td", {className: "num"}, 48),
            React.createElement("td", {className: "num"}, 49),
            React.createElement("td", {className: "num"}, 51),
            React.createElement("td", {className: "num"}, 61),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "treasury",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.treasury.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/sxYI"},
                "Fundraising"
              )
            ),

            React.createElement("td", {className: "num"}, 8),
            React.createElement("td", {className: "num"}, 18),
            React.createElement("td", {className: "num"}, 23),
            React.createElement("td", {className: "num"}, 23),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "fundraising",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.fundraising.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,

            React.createElement(
              "td",
              {className: "indented"},

              React.createElement(
                "a",
                {href: "https://s.apache.org/4LdI"},
                "General & Administrative"
              )
            ),

            React.createElement("td", {className: "num"}, 114),
            React.createElement("td", {className: "num"}, 50),
            React.createElement("td", {className: "num"}, 139),
            React.createElement("td", {className: "num"}, 300),

            React.createElement(
              "td",
              {className: "num"},

              React.createElement("input", {
                id: "generalAndAdministrative",
                onBlur: this.change,
                disabled: this.state.disabled,
                defaultValue: this.state.budget.generalAndAdministrative.toLocaleString()
              })
            )
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----"),
            React.createElement("td", {className: "num"}, "----")
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {className: "indented"}, "Total Expense"),

            React.createElement(
              "td",
              {className: "num"},
              (1219).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (1390).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (1693).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num"},
              (2199).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num", id: "expense"},
              this.state.budget.expense.toLocaleString()
            )
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {colSpan: 6})
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", null, "Net"),
            React.createElement("td", {className: "num"}, -130),
            React.createElement("td", {className: "num"}, -369),
            React.createElement("td", {className: "num"}, -552),
            React.createElement("td", {className: "num"}, -993),

            React.createElement(
              "td",

              {
                className: "num " + (this.state.budget.net < 0 ? "danger" : "success"),
                id: "net"
              },

              this.state.budget.net.toLocaleString()
            )
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", {colSpan: 6})
          ),

          React.createElement(
            "tr",
            null,
            React.createElement("td", null, "Cash"),

            React.createElement(
              "td",
              {className: "num"},
              (1656).toLocaleString()
            ),

            React.createElement("td", {className: "num"}, 290),
            React.createElement("td", {className: "num"}, -259),

            React.createElement(
              "td",
              {className: "num"},
              (-1403).toLocaleString()
            ),

            React.createElement(
              "td",
              {className: "num", id: "cash"},
              this.state.budget.cash.toLocaleString()
            )
          )
        )
      ),

      React.createElement(
        "p",
        null,
        "Units are in thousands of dollars US."
      )
    )
  },

  // evaluate computed fields
  recalc: function() {
    this.state.budget.income = this.state.budget.donations + this.state.budget.sponsorship + 28 + 4;
    this.state.budget.expense = this.state.budget.infrastructure + 27 + this.state.budget.publicity + this.state.budget.brandManagement + this.state.budget.conferences + this.state.budget.travelAssistance + this.state.budget.treasury + this.state.budget.fundraising + this.state.budget.generalAndAdministrative;
    this.state.budget.net = this.state.budget.income - this.state.budget.expense;
    this.state.budget.cash = 1656 - 2 * 130 + 3 * this.state.budget.net
  },

  // update budget item when an input field changes
  change: function(event) {
    var self = this;

    this.state.budget[event.target.id] = parseInt(event.target.value.replace(
      /\D/g,
      ""
    )) || 0;

    event.target.value = this.state.budget[event.target.id].toLocaleString();
    this.recalc();

    if (Server.role == "secretary" && Minutes.started) {
      post(
        "budget",
        {agenda: Agenda.file, budget: this.state.budget},

        function(budget) {
          if (budget) self.setState({budget: budget})
        }
      )
    };

    this.forceUpdate()
  },

  // receive updated budget values
  componentWillReceiveProps: function($$props) {
    var budget = Minutes.get("budget");

    if (budget && budget != this.state.budget && Minutes.started) {
      for (var item in budget) {
        var element = document.getElementById(item);

        if (element.tagName == "INPUT") {
          element.value = budget[item].toLocaleString()
        } else {
          element.textContent = budget[item].toLocaleString()
        }
      };

      this.setState({budget: budget});
      if (Server.role != "secretary") this.setState({disabled: true})
    }
  }
});

//
// This component handles both add and edit comment actions.  The save
// button is disabled until the comment is changed.  A delete button is
// provided to clear the comment if it isn't already empty.
//
// When the save button is pushed, a POST request is sent to the server.
// When a response is received, the pending status is updated and the
// form is dismissed.
//
var AddComment = React.createClass({
  displayName: "AddComment",

  statics: {button: {
    text: "add comment",
    class: "btn_primary",
    data_toggle: "modal",
    data_target: "#comment-form"
  }},

  getInitialState: function() {
    return {
      base: this.props.item.pending,
      comment: this.props.item.pending,
      disabled: false,
      checked: this.props.item.flagged
    }
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [ModalDialog, {id: "comment-form", color: "commented"}];

      // header
      if (self.state.base) {
        $_.push(React.createElement("h4", null, "Edit comment"))
      } else {
        $_.push(React.createElement("h4", null, "Enter a comment"))
      };

      //input field: initials
      $_.push(React.createElement("input", {
        id: "comment-initials",
        label: "Initials",
        placeholder: "initials",
        disabled: self.state.disabled,
        defaultValue: self.props.server.pending.initials || self.props.server.initials
      }));

      //input field: comment text
      $_.push(React.createElement("textarea", {
        id: "comment-text",
        value: self.state.comment,
        label: "Comment",
        placeholder: "comment",
        rows: 5,
        onChange: self.change,
        disabled: self.state.disabled
      }));

      if (Server.role == "director" && /^[A-Z]+$/.test(self.props.item.attach)) {
        $_.push(React.createElement("input", {
          id: "flag",
          type: "checkbox",
          label: "item requires discussion or follow up",
          onChange: self.flag,
          checked: self.state.checked
        }))
      };

      // footer buttons
      $_.push(React.createElement(
        "button",

        {
          className: "btn-default",
          "data-dismiss": "modal",
          disabled: self.state.disabled
        },

        "Cancel"
      ));

      if (self.state.comment) {
        $_.push(React.createElement(
          "button",

          {
            className: "btn-warning",
            onClick: self.delete,
            disabled: self.state.disabled
          },

          "Delete"
        ))
      };

      $_.push(React.createElement(
        "button",

        {
          className: "btn-primary",
          onClick: self.save,
          disabled: self.state.disabled || self.state.comment == self.state.base
        },

        "Save"
      ));

      return $_
    }())
  },

  // autofocus on comment text
  componentDidMount: function() {
    jQuery("#comment-form").on("shown.bs.modal", function() {
      document.getElementById("comment-text").focus()
    })
  },

  // update comment when textarea changes, triggering hiding/showing the
  // Delete button and enabling/disabling the Save button.
  change: function(event) {
    this.setState({comment: event.target.value})
  },

  // when item changes, reset base and comment
  componentWillReceiveProps: function(newprops) {
    if (newprops.item.href != this.props.item.href) {
      this.setState({
        checked: newprops.item.flagged,
        base: newprops.item.pending || "",
        comment: newprops.item.pending || ""
      })
    }
  },

  // when delete button is pushed, clear the comment
  delete: function(event) {
    this.setState({comment: ""})
  },

  // when save button is pushed, post comment and dismiss modal when complete
  save: function(event) {
    var self = this;
    Server.initials = document.getElementById("comment-initials").value;

    var data = {
      agenda: Agenda.file,
      attach: this.props.item.attach,
      initials: Server.initials,
      comment: this.state.comment
    };

    this.setState({disabled: true});

    post("comment", data, function(pending) {
      jQuery("#comment-form").modal("hide");
      document.body.classList.remove("modal-open");
      self.setState({disabled: false});
      Pending.load(pending)
    })
  },

  flag: function(event) {
    this.setState({checked: !this.state.checked});

    var data = {
      agenda: Agenda.file,
      initials: Server.initials,
      attach: this.props.item.attach,
      request: (event.target.checked ? "flag" : "unflag")
    };

    post("approve", data, function(pending) {Pending.load(pending)})
  }
});

var AddMinutes = React.createClass({
  displayName: "AddMinutes",

  statics: {button: {
    text: "add minutes",
    class: "btn_primary",
    data_toggle: "modal",
    data_target: "#minute-form"
  }},

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [
        ModalDialog,
        {className: "wide-form", id: "minute-form", color: "commented"}
      ];

      $_.push(React.createElement(
        "h4",
        {className: "commented"},
        "Minutes"
      ));

      // either a large text area, or a slightly smaller text area
      // followed by comments
      if (self.props.item.comments.length == 0) {
        $_.push(React.createElement("textarea", {
          className: "form-control",
          id: "minute-text",
          rows: 17,
          tabIndex: 1,
          placeholder: "minutes",
          value: self.state.draft,

          onChange: function(event) {
            self.setState({draft: event.target.value})
          }
        }))
      } else {
        $_.push(React.createElement("textarea", {
          className: "form-control",
          id: "minute-text",
          rows: 12,
          tabIndex: 1,
          placeholder: "minutes",
          value: self.state.draft,

          onChange: function(event) {
            self.setState({draft: event.target.value})
          }
        }));

        $_.push(React.createElement("h3", null, "Comments"));

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["div", {id: "minute-comments"}];

          self.props.item.comments.forEach(function(comment) {
            $_.push(React.createElement("pre", {className: "comment"}, comment))
          });

          return $_
        }()))
      };

      // action items
      $_.push(React.createElement(
        "div",
        {className: "row", style: {marginTop: "1em"}},

        React.createElement(
          "button",

          {
            className: "btn btn-sm btn-info col-md-offset-1 col-md-1",
            onClick: self.addAI,
            disabled: !self.state.ai_owner || !self.state.ai_text
          },

          "+ AI"
        ),

        React.createElement(
          "label",
          {className: "col-md-2"},

          React.createElement.apply(React, function() {
            var $_ = [
              "select",

              {value: self.state.ai_owner, onChange: function(event) {
                self.setState({ai_owner: event.target.value})
              }}
            ];

            Minutes.attendee_names.forEach(function(name) {
              $_.push(React.createElement("option", null, name))
            });

            return $_
          }())
        ),

        React.createElement("textarea", {
          className: "col-md-7",
          value: self.state.ai_text,
          rows: 1,
          cols: 40,
          tabIndex: 2,

          onChange: function(event) {
            self.setState({ai_text: event.target.value})
          }
        })
      ));

      // variable number of buttons
      $_.push(React.createElement(
        "button",

        {
          className: "btn-default",
          type: "button",
          "data-dismiss": "modal",

          onClick: function() {
            self.setState({draft: self.state.base})
          }
        },

        "Cancel"
      ));

      if (self.state.base) {
        $_.push(React.createElement(
          "button",

          {className: "btn-warning", type: "button", onClick: function() {
            self.setState({draft: ""})
          }},

          "Delete"
        ))
      };

      // special buttons for prior months draft minutes
      if (/^3\w/.test(self.props.item.attach)) {
        $_.push(React.createElement(
          "button",

          {
            className: "btn-warning",
            type: "button",
            onClick: self.save,
            disabled: self.state.disabled
          },

          "Tabled"
        ));

        $_.push(React.createElement(
          "button",

          {
            className: "btn-success",
            type: "button",
            onClick: self.save,
            disabled: self.state.disabled
          },

          "Approved"
        ))
      };

      $_.push(React.createElement(
        "button",
        {className: self.reflow_color(), onClick: self.reflow},
        "Reflow"
      ));

      $_.push(React.createElement(
        "button",

        {
          className: "btn-primary",
          type: "button",
          onClick: self.save,
          disabled: self.state.disabled || self.state.base == self.state.draft
        },

        "Save"
      ));

      return $_
    }())
  },

  // autofocus on minute text
  componentDidMount: function() {
    jQuery("#minute-form").on("shown.bs.modal", function() {
      document.getElementById("minute-text").focus()
    })
  },

  // when initially displayed, set various fields to match the item
  componentWillMount: function() {
    this.setup(this.props.item)
  },

  // when item changes, reset various fields to match
  componentWillReceiveProps: function(newprops) {
    if (newprops.item.href != this.props.item.href) this.setup(newprops.item)
  },

  // reset base, draft minutes, shepherd, default ai_text, and indent
  setup: function(item) {
    this.setState({base: draft = Minutes.get(item.title) || ""});

    if (/^(8|9|1\d)\.$/.test(item.attach)) {
      draft = draft || item.text
    } else if (!item.text) {
      this.setState({ai_text: "pursue a report for " + item.title})
    };

    this.setState({
      draft: draft,
      ai_owner: item.shepherd,
      indent: (/^\w+$/.test(this.props.item.attach) ? 8 : 4)
    })
  },

  // add an additional AI to the draft minutes for this item
  addAI: function(event) {
    var $draft = this.state.draft;
    if ($draft) $draft += "\n";
    $draft += "@" + this.state.ai_owner + ": " + this.state.ai_text;

    this.setState({
      ai_owner: this.props.item.shepherd,
      ai_text: "",
      draft: $draft
    })
  },

  // determine if reflow button should be default or danger color
  reflow_color: function() {
    var width = 78 - this.state.indent;

    if (!this.state.draft || this.state.draft.split("\n").every(function(line) {
      return line.length <= width
    })) {
      return "btn-default"
    } else {
      return "btn-danger"
    }
  },

  reflow: function() {
    console.log("reflowing");

    console.log(Flow.text(
      this.state.draft || "",
      new Array(this.state.indent + 1).join(" ")
    ));

    this.setState({draft: Flow.text(
      this.state.draft || "",
      new Array(this.state.indent + 1).join(" ")
    )})
  },

  save: function(event) {
    var self = this;
    var text;

    switch (event.target.textContent) {
    case "Save":
      text = this.state.draft;
      break;

    case "Tabled":
      text = "tabled";
      break;

    case "Approved":
      text = "approved"
    };

    var data = {
      agenda: Agenda.file,
      title: this.props.item.title,
      text: text
    };

    this.setState({disabled: true});

    post("minute", data, function(minutes) {
      Minutes.load(minutes);
      self.setup(self.props.item);
      self.setState({disabled: false});
      jQuery("#minute-form").modal("hide");
      document.body.classList.remove("modal-open")
    })
  }
});

//
// Approve/Unapprove a report
//
var Approve = React.createClass({
  displayName: "Approve",

  getInitialState: function() {
    return {disabled: false, request: "approve"}
  },

  // render a single button
  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled
      },

      this.state.request
    )
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // set request (and button text) depending on whether or not the
  // not this items was previously approved
  componentWillReceiveProps: function($$props) {
    if (Pending.approved.indexOf($$props.item.attach) != -1) {
      this.setState({request: "unapprove"})
    } else if (Pending.unapproved.indexOf($$props.item.attach) != -1) {
      this.setState({request: "approve"})
    } else if ($$props.item.approved && $$props.item.approved.indexOf(Server.initials) != -1) {
      this.setState({request: "unapprove"})
    } else {
      this.setState({request: "approve"})
    }
  },

  // when button is clicked, send request
  click: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      initials: Server.initials,
      attach: this.props.item.attach,
      request: this.state.request
    };

    this.setState({disabled: true});

    post("approve", data, function(pending) {
      self.setState({disabled: false});
      Pending.load(pending)
    })
  }
});

//
// Indicate intention to attend / regrets for meeting
//
var Attend = React.createClass({
  displayName: "Attend",

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled
      },

      (this.state.attending ? "regrets" : "attend")
    )
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // match person by either userid or name
  componentWillReceiveProps: function($$props) {
    var person = $$props.item.people[Server.userid];

    if (person) {
      this.setState({attending: person.attending})
    } else {
      this.setState({attending: false});

      for (var id in $$props.item.people) {
        person = $$props.item.people[id];

        if (person.name == Server.username) {
          this.setState({attending: person.attending})
        }
      }
    }
  },

  click: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      action: (this.state.attending ? "regrets" : "attend"),
      name: Server.username,
      userid: Server.userid
    };

    this.setState({disabled: true});

    post("attend", data, function(response) {
      self.setState({disabled: false});
      Agenda.load(response.agenda, response.digest)
    })
  }
});

//
// Commit pending comments and approvals.  Build a default commit message,
// and allow it to be changed.
//
var Commit = React.createClass({
  displayName: "Commit",

  statics: {button: {
    text: "commit",
    class: "btn_primary",
    data_toggle: "modal",
    data_target: "#commit-form"
  }},

  getInitialState: function() {
    return {disabled: false}
  },

  // commit form: allow the user to confirm or edit the commit message
  render: function() {
    var self = this;

    return React.createElement(
      ModalDialog,
      {id: "commit-form", color: "blank"},
      React.createElement("h4", null, "Commit message"),

      React.createElement("textarea", {
        id: "commit-text",
        value: this.state.message,
        rows: 5,
        disabled: this.state.disabled,
        label: "Commit message",

        onChange: function(event) {
          self.setState({message: event.target.value})
        }
      }),

      React.createElement(
        "button",
        {className: "btn-default", "data-dismiss": "modal"},
        "Close"
      ),

      React.createElement(
        "button",

        {
          className: "btn-primary",
          onClick: this.click,
          disabled: this.state.disabled
        },

        "Submit"
      )
    )
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // autofocus on comment text
  componentDidMount: function() {
    jQuery("#commit-form").on("shown.bs.modal", function() {
      document.getElementById("commit-text").focus()
    })
  },

  // update message on re-display
  componentWillReceiveProps: function($$props) {
    var pending = $$props.server.pending;
    var messages = [];

    // common format for message lines
    var append = function(title, list) {
      if (!list) return;
      var titles;

      if (list.length > 0 && list.length < 6) {
        titles = [];

        Agenda.index.forEach(function(item) {
          if (list.indexOf(item.attach) != -1) titles.push(item.title)
        });

        messages.push(title + " " + titles.join(", "))
      } else if (list.length > 1) {
        messages.push(title + " " + list.length + " reports")
      }
    };

    append("Approve", pending.approved);
    append("Unapprove", pending.unapproved);
    append("Flag", pending.flagged);
    append("Unflag", pending.unflagged);

    // list (or number) of comments made with this commit
    var comments = Object.keys(pending.comments).length;
    var titles;

    if (comments > 0 && comments < 6) {
      titles = [];

      Agenda.index.forEach(function(item) {
        if (pending.comments[item.attach]) titles.push(item.title)
      });

      messages.push("Comment on " + titles.join(", "))
    } else if (comments > 1) {
      messages.push("Comment on " + comments + " reports")
    };

    // identify (or number) action item(s) updated with this commit
    var item, text;

    if (pending.status) {
      if (pending.status.length == 1) {
        item = pending.status[0];
        text = item.text;

        if (item.pmc || item.date) {
          text += " [";
          if (item.pmc) text += " " + item.pmc;
          if (item.date) text += " " + item.date;
          text += " ]"
        };

        messages.push("Update AI: " + text)
      } else if (pending.status.length > 1) {
        messages.push("Update " + pending.status.length + " action items")
      }
    };

    this.setState({message: messages.join("\n")})
  },

  // update message when textarea changes
  change: function(event) {
    this.setState({message: event.target.value})
  },

  // on click, disable the input fields and buttons and submit
  click: function(event) {
    var self = this;
    this.setState({disabled: true});

    post(
      "commit",
      {message: this.state.message, initials: Pending.initials},

      function(response) {
        Agenda.load(response.agenda, response.digest);
        Pending.load(response.pending);
        self.setState({disabled: false});

        // delay jQuery updates to give React a chance to make updates first
        setTimeout(
          function() {
            jQuery("#commit-form").modal("hide");
            document.body.classList.remove("modal-open");
            jQuery(".modal-backdrop").remove()
          },

          300
        )
      }
    )
  }
});

var DraftMinutes = React.createClass({
  displayName: "DraftMinutes",

  statics: {button: {
    text: "draft minutes",
    class: "btn_danger",
    data_toggle: "modal",
    data_target: "#draft-minute-form"
  }},

  getInitialState: function() {
    return {disabled: true}
  },

  render: function() {
    var self = this;

    return React.createElement(
      ModalDialog,
      {className: "wide-form", id: "draft-minute-form", color: "commented"},

      React.createElement(
        "h4",
        {className: "commented"},
        "Commit Draft Minutes to SVN"
      ),

      React.createElement("textarea", {
        className: "form-control",
        id: "draft-minute-text",
        rows: 17,
        tabIndex: 1,
        placeholder: "minutes",
        value: this.state.draft,
        disabled: this.state.disabled,

        onChange: function(event) {
          self.setState({draft: event.target.value})
        }
      }),

      React.createElement(
        "button",
        {className: "btn-default", type: "button", "data-dismiss": "modal"},
        "Cancel"
      ),

      React.createElement(
        "button",

        {
          className: "btn-primary",
          type: "button",
          onClick: this.save,
          disabled: this.state.disabled
        },

        "Save"
      )
    )
  },

  // autofocus on minute text; fetch draft
  componentDidMount: function() {
    var self = this;
    this.setState({draft: ""});

    jQuery("#draft-minute-form").on("shown.bs.modal", function() {
      retrieve(
        "draft/" + Agenda.title.replace(/\-/g, "_"),
        "text",

        function(draft) {
          document.getElementById("draft-minute-text").focus();
          self.setState({disabled: false, draft: draft});
          jQuery("#draft-minute-text").animate({scrollTop: 0})
        }
      )
    })
  },

  save: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      message: "Draft minutes for " + Agenda.title,
      text: this.state.draft
    };

    this.setState({disabled: true});

    post("draft", data, function() {
      self.setState({disabled: false});
      jQuery("#draft-minute-form").modal("hide");
      document.body.classList.remove("modal-open")
    })
  }
});

//
// A button that mark all comments as 'seen', with an undo option
//
var MarkSeen = React.createClass({
  displayName: "MarkSeen",

  getInitialState: function() {
    this.state = {disabled: false, label: "mark seen"};
    MarkSeen.undo = null;
    return this.state
  },

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled
      },

      this.state.label
    )
  },

  click: function(event) {
    var self = this;
    this.setState({disabled: true});
    var seen;

    if (MarkSeen.undo) {
      seen = MarkSeen.undo
    } else {
      seen = {};

      Agenda.index.forEach(function(item) {
        if (item.comments && item.comments.length != 0) {
          seen[item.attach] = item.comments
        }
      })
    };

    post(
      "markseen",
      {seen: seen, agenda: Agenda.file},

      function(pending) {
        self.setState({disabled: false});

        if (MarkSeen.undo) {
          MarkSeen.undo = null;
          self.setState({label: "mark seen"})
        } else {
          MarkSeen.undo = Pending.seen;
          self.setState({label: "undo mark"})
        };

        Pending.load(pending)
      }
    )
  }
});

//
// Message area for backchannel
//
var Message = React.createClass({
  displayName: "Message",

  getInitialState: function() {
    return {disabled: false, message: ""}
  },

  // render an input area in the button area (a very w-i-d-e button)
  render: function() {
    var self = this;

    return React.createElement(
      "form",
      {onSubmit: this.sendMessage},

      React.createElement("input", {
        id: "chatMessage",
        value: this.state.message,

        onChange: function(event) {
          self.setState({message: event.target.value})
        }
      })
    )
  },

  // autofocus on the chat message when the page is initially displayed
  componentDidMount: function() {
    document.getElementById("chatMessage").focus()
  },

  // send message to server
  sendMessage: function(event) {
    var self = this;
    event.stopPropagation();
    event.preventDefault();

    if (this.state.message) {
      post(
        "message",
        {agenda: Agenda.file, text: this.state.message},

        function(message) {
          Chat.add(message);
          self.setState({message: ""})
        }
      )
    };

    return false
  }
});

//
// Post or edit a report or resolution
//
// For new resolutions, allow entry of title, but not commit message
// For everything else, allow modification of commit message, but not title
var Post = React.createClass({
  displayName: "Post",

  statics: {button: {
    text: "post report",
    class: "btn_primary",
    data_toggle: "modal",
    data_target: "#post-report-form"
  }},

  getInitialState: function() {
    return {disabled: false, alerted: false, edited: false}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [
        ModalDialog,
        {className: "wide-form", id: "post-report-form", color: "commented"}
      ];

      $_.push(React.createElement("h4", null, self.state.header));

      //input field: title
      if (self.props.button.text == "add resolution") {
        $_.push(React.createElement("input", {
          id: "post-report-title",
          label: "title",
          disabled: self.state.disabled,
          placeholder: "title",
          value: self.state.title,
          onFocus: self.default_title,

          onChange: function(event) {
            self.setState({title: event.target.value})
          }
        }))
      };

      //input field: report text
      $_.push(React.createElement("textarea", {
        id: "post-report-text",
        label: self.state.label,
        value: self.state.report,
        placeholder: self.state.label,
        rows: 17,
        disabled: self.state.disabled,
        onChange: self.change_text
      }));

      // upload of spreadsheet from virtual
      if (self.props.item.title == "Treasurer") {
        $_.push(React.createElement("form", null, React.createElement(
          "div",
          {className: "form-group"},

          React.createElement(
            "label",
            {htmlFor: "upload"},
            "financial spreadsheet from virtual"
          ),

          React.createElement("input", {
            id: "upload",
            type: "file",
            value: self.state.upload,

            onChange: function(event) {
              self.setState({upload: event.target.value})
            }
          }),

          React.createElement(
            "button",

            {
              className: "btn btn-primary",
              onClick: self.upload,
              disabled: self.state.disabled || !self.state.upload
            },

            "Upload"
          )
        )))
      };

      //input field: commit_message
      if (self.props.button.text != "add resolution") {
        $_.push(React.createElement("input", {
          id: "post-report-message",
          label: "commit message",
          disabled: self.state.disabled,
          value: self.state.message,

          onChange: function(event) {
            self.setState({message: event.target.value})
          }
        }))
      };

      $_.push(React.createElement(
        "button",

        {
          className: "btn-default",
          "data-dismiss": "modal",
          disabled: self.state.disabled
        },

        "Cancel"
      ));

      $_.push(React.createElement(
        "button",
        {className: self.reflow_color(), onClick: self.reflow},
        "Reflow"
      ));

      $_.push(React.createElement(
        "button",

        {
          className: "btn-primary",
          onClick: self.submit,
          disabled: !self.ready()
        },

        "Submit"
      ));

      return $_
    }())
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // autofocus on report/resolution title/text
  componentDidMount: function() {
    var self = this;

    jQuery("#post-report-form").on("shown.bs.modal", function() {
      if (self.props.button.text == "add resolution") {
        document.getElementById("post-report-title").focus()
      } else {
        document.getElementById("post-report-text").focus()
      }
    })
  },

  // match form title, input label, and commit message with button text
  componentWillReceiveProps: function(newprops) {
    var $edited = this.state.edited;

    switch (newprops.button.text) {
    case "post report":

      this.setState({
        header: "Post Report",
        label: "report",
        message: "Post " + newprops.item.title + " Report"
      });

      break;

    case "edit report":

      this.setState({
        header: "Edit Report",
        label: "report",
        message: "Edit " + newprops.item.title + " Report"
      });

      break;

    case "add resolution":

      this.setState({
        header: "Add Resolution",
        label: "resolution",
        title: ""
      });

      break;

    case "edit resolution":

      this.setState({
        header: "Edit Resolution",
        label: "resolution",
        message: "Edit " + newprops.item.title + " Resolution"
      })
    };

    var text, $digest, $alerted;

    if (!$edited || newprops.item.attach != this.props.item.attach) {
      text = newprops.item.text || "";

      if (newprops.item.title == "President") {
        text = text.replace(
          /\s*Additionally, please see Attachments \d through \d\./,
          ""
        )
      };

      this.setState({report: text});
      $digest = newprops.item.digest;
      $alerted = false;
      $edited = false
    } else if (!$alerted && $edited && $digest != newprops.item.digest) {
      alert("edit conflict");
      $alerted = true
    };

    if (newprops.button.text == "add resolution" || /^[47]/.test(newprops.item.attach)) {
      this.setState({indent: "        "})
    } else {
      this.setState({indent: ""})
    };

    this.setState({edited: $edited, digest: $digest, alerted: $alerted})
  },

  // default title based on common resolution patterns
  default_title: function(event) {
    if (this.state.title) return;
    var match = null;

    if (match = this.state.report.match(/appointed\s+to\s+the\s+office\s+of\s+Vice\s+President,\s+Apache\s+(.*?),/)) {
      this.setState({title: "Change the Apache " + match[1] + " Project Chair"})
    } else if (match = this.state.report.match(/to\s+be\s+known\s+as\s+the\s+"Apache\s+(.*?)\s+Project",\s+be\s+and\s+hereby\s+is\s+established/)) {
      this.setState({title: "Establish the Apache " + match[1] + " Project"})
    } else if (match = this.state.report.match(/the\s+Apache\s+(.*?)\s+project\s+is\s+hereby\s+terminated/)) {
      this.setState({title: "Terminate the Apache " + match[1] + " Project"})
    }
  },

  // track changes to text value
  change_text: function(event) {
    this.setState({report: event.target.value, edited: true})
  },

  // determine if reflow button should be default or danger color
  reflow_color: function() {
    var width = 80 - this.state.indent.length;

    if (this.state.report.split("\n").every(function(line) {
      return line.length <= width
    })) {
      return "btn-default"
    } else {
      return "btn-danger"
    }
  },

  // perform a reflow of report text
  reflow: function() {
    var report = this.state.report;

    // remove indentation
    var regex = /^( +)\S/gm;
    var indents = [];

    while (result = regex.exec(report)) {
      indents.push(result[1].length)
    };

    if (indents.length != 0) {
      report = report.replace(
        new RegExp("^" + new Array(Math.min.apply(Math, indents) + 1).join(" "), "gm"),
        ""
      )
    };

    this.setState({report: Flow.text(report, this.state.indent)})
  },

  // determine if the form is ready to be submitted
  ready: function() {
    if (this.state.disabled) return false;

    if (this.props.button.text == "add resolution") {
      return this.state.report != "" && this.state.title != ""
    } else {
      return this.state.report != this.props.item.text && this.state.message != ""
    }
  },

  // upload contents of spreadsheet in base64; append extracted table to report
  upload: function(event) {
    var self = this;
    this.setState({disabled: true});
    event.preventDefault();
    var reader = new FileReader;

    reader.onload = function(event) {
      var result = event.target.result;

      var base64 = btoa(String.fromCharCode.apply(
        null,
        new Uint8Array(result)
      ));

      post("financials", {spreadsheet: base64}, function(response) {
        var report = self.state.report;
        if (report && report.slice(-1) != "\n") report += "\n";
        if (report) report += "\n";
        report += response.table;
        self.change_text({target: {value: report}});
        self.setState({upload: null, disabled: false})
      })
    };

    reader.readAsArrayBuffer(document.getElementById("upload").files[0])
  },

  // when save button is pushed, post comment and dismiss modal when complete
  submit: function(event) {
    var self = this;
    this.setState({edited: false});
    var data;

    if (this.props.button.text == "add resolution") {
      data = {
        agenda: Agenda.file,
        attach: "7?",
        title: this.state.title,
        report: this.state.report
      }
    } else {
      data = {
        agenda: Agenda.file,
        attach: this.props.item.attach,
        digest: this.state.digest,
        message: this.state.message,
        report: this.state.report
      }
    };

    this.setState({disabled: true});

    post("post", data, function(response) {
      jQuery("#post-report-form").modal("hide");
      document.body.classList.remove("modal-open");
      self.setState({disabled: false});
      Agenda.load(response.agenda, response.digest)
    })
  }
});

//
// Indicate intention to attend / regrets for meeting
//
var PostActions = React.createClass({
  displayName: "PostActions",

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled || SelectActions.list.length == 0
      },

      "post actions"
    )
  },

  click: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      message: "Post Action Items",
      actions: SelectActions.list
    };

    this.setState({disabled: true});

    post("post-actions", data, function(response) {
      self.setState({disabled: false});
      Agenda.load(response.agenda, response.digest)
    })
  }
});

var PublishMinutes = React.createClass({
  displayName: "PublishMinutes",

  statics: {button: {
    text: "publish minutes",
    class: "btn_danger",
    data_toggle: "modal",
    data_target: "#publish-minutes-form"
  }},

  getInitialState: function() {
    return {disabled: false, previous_title: null}
  },

  render: function() {
    var self = this;

    return React.createElement(
      ModalDialog,

      {
        className: "wide-form",
        id: "publish-minutes-form",
        color: "commented"
      },

      React.createElement(
        "h4",
        {className: "commented"},
        "Publish Minutes onto the ASF web site"
      ),

      React.createElement("textarea", {
        className: "form-control",
        id: "summary-text",
        rows: 10,
        tabIndex: 1,
        value: this.state.summary,
        disabled: this.state.disabled,
        label: "Minutes summary",

        onChange: function(event) {
          self.setState({summary: event.target.value})
        }
      }),

      React.createElement("input", {
        id: "message",
        label: "Commit message",
        value: this.state.message,
        disabled: this.state.disabled,

        onChange: function(event) {
          self.setState({message: event.target.value})
        }
      }),

      React.createElement(
        "button",
        {className: "btn-default", type: "button", "data-dismiss": "modal"},
        "Cancel"
      ),

      React.createElement(
        "button",

        {
          className: "btn-primary",
          type: "button",
          onClick: this.publish,
          disabled: this.state.disabled
        },

        "Submit"
      )
    )
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // when page title changes, update form values
  componentWillReceiveProps: function($$props) {
    var self = this;
    var date, url;

    if ($$props.item.title != this.state.previous_title) {
      if (!$$props.item.attach) {
        // Index page for a path month's agenda
        this.summary(Agenda.index, Agenda.title.replace(/\-/g, "_"))
      } else if (typeof XMLHttpRequest !== 'undefined') {
        // Minutes from previous meetings section of the agenda
        date = ($$props.item.text.match(/board_minutes_(\d+_\d+_\d+)\.txt/) || [])[1];

        url = document.baseURI.replace(
          new RegExp("[-\\d]+/$"),
          date.replace(/_/g, "-")
        ) + ".json";

        retrieve(url, "json", function(agenda) {self.summary(agenda, date)})
      };

      this.setState({previous_title: $$props.item.title})
    }
  },

  // autofocus on minute text
  componentDidMount: function() {
    jQuery("#publish-minutes-form").on("shown.bs.modal", function() {
      document.getElementById("summary-text").focus()
    })
  },

  // compute default summary for web site and commit message
  summary: function(agenda, date) {
    var summary = ("- [" + this.formatDate(date) + "]") + ("(../records/minutes/" + date.slice(
      0,
      4
    ) + "/board_minutes_" + date + ".txt)\n");

    agenda.forEach(function(item) {
      if (/^7\w$/.test(item.attach)) {
        if (item.minutes && item.minutes.toLowerCase().indexOf("tabled") != -1) {
          summary += "    * " + item.title.trim() + " (tabled)\n"
        } else {
          summary += "    * " + item.title.trim() + "\n"
        }
      }
    });

    this.setState({
      date: date,
      summary: summary,
      message: "Publish " + this.formatDate(date) + " minutes"
    })
  },

  // convert date to displayable form
  formatDate: function(date) {
    var months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];

    date = new Date(date.replace(/_/g, "/"));
    return date.getDate() + " " + months[date.getMonth()] + " " + (date.getYear() + 1900)
  },

  publish: function(event) {
    var self = this;

    var data = {
      date: this.state.date,
      summary: this.state.summary,
      message: this.state.message
    };

    this.setState({disabled: true});

    post("publish", data, function(drafts) {
      self.setState({disabled: false});
      Server.drafts = drafts;
      jQuery("#publish-minutes-form").modal("hide");
      document.body.classList.remove("modal-open");
      window.open("https://cms.apache.org/www/publish", "_blank").focus()
    })
  }
});

//
// Send initial and final reminders.  Note that this is a form (with an
// associated button) as well as a second button.
//
var InitialReminder = React.createClass({
  displayName: "InitialReminder",

  statics: {button: {
    text: "send initial reminders",
    class: "btn_primary",
    data_toggle: "modal",
    data_target: "#reminder-form"
  }},

  getInitialState: function() {
    return {disabled: true, subject: "", message: ""}
  },

  // fetch email template
  loadText: function(event) {
    var self = this;
    var reminder;

    if (event.target.textContent == "send initial reminders") {
      reminder = "reminder1"
    } else {
      reminder = "reminder2"
    };

    retrieve(reminder, "json", function(response) {
      self.setState({
        subject: response.subject,
        message: response.body,
        disabled: false
      })
    })
  },

  // wire up event handlers
  componentDidMount: function() {
    var self = this;

    Array.prototype.slice.call(document.querySelectorAll(".btn-primary")).forEach(function(button) {
      if (button.getAttribute("data-target") == "#reminder-form") {
        button.onclick = self.loadText
      }
    })
  },

  // commit form: allow the user to confirm or edit the commit message
  render: function() {
    var self = this;

    return React.createElement(
      ModalDialog,
      {className: "wide-form", id: "reminder-form", color: "blank"},
      React.createElement("h4", null, "Email message"),

      React.createElement("input", {
        id: "email-subject",
        value: this.state.subject,
        disabled: this.state.disabled,
        label: "subject",
        placeholder: "loading...",

        onChange: function(event) {
          self.setState({subject: event.target.value})
        }
      }),

      React.createElement("textarea", {
        id: "email-text",
        value: this.state.message,
        rows: 12,
        disabled: this.state.disabled,
        label: "body",
        placeholder: "loading...",

        onChange: function(event) {
          self.setState({message: event.target.value})
        }
      }),

      React.createElement(
        "button",
        {className: "btn-default", "data-dismiss": "modal"},
        "Close"
      ),

      React.createElement(
        "button",

        {
          className: "btn-info",
          onClick: this.click,
          disabled: this.state.disabled
        },

        "Dry Run"
      ),

      React.createElement(
        "button",

        {
          className: "btn-primary",
          onClick: this.click,
          disabled: this.state.disabled
        },

        "Submit"
      )
    )
  },

  // on click, disable the input fields and buttons and submit
  click: function(event) {
    var self = this;
    this.setState({disabled: true});
    var dryrun = event.target.textContent == "Dry Run";

    // data to be sent to the server
    var data = {
      dryrun: dryrun,
      agenda: Agenda.file,
      subject: this.state.subject,
      message: this.state.message,
      pmcs: []
    };

    // collect up a list of PMCs that are checked
    Array.prototype.slice.call(document.querySelectorAll("input[type=checkbox]")).forEach(function(input) {
      if (input.checked) data.pmcs.push(input.value)
    });

    post("send-reminders", data, function(response) {
      if (!response) {
        alert("Server error - check console log")
      } else if (dryrun) {
        console.log(response);
        alert("Dry run - check console log")
      } else if (response.count == data.pmcs.length) {
        alert("Reminders have been sent to: " + data.pmcs.join(", ") + ".")
      } else if (response.count && response.unsent) {
        alert("Error: no emails were sent to " + response.unsent.join(", "))
      } else {
        alert("No reminders were sent")
      };

      self.setState({disabled: false});
      jQuery("#reminder-form").modal("hide");
      document.body.classList.remove("modal-open")
    })
  }
});

//
// A button for final reminders
//
var FinalReminder = React.createClass({
  displayName: "FinalReminder",

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        "data-toggle": "modal",
        "data-target": "#reminder-form"
      },

      "send final reminders"
    )
  }
});

//
// A button that will do a 'svn update' of the agenda on the server
//
var Refresh = React.createClass({
  displayName: "Refresh",

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled
      },

      "refresh"
    )
  },

  click: function(event) {
    var self = this;
    this.setState({disabled: true});

    post("refresh", {agenda: Agenda.file}, function(response) {
      self.setState({disabled: false});
      Agenda.load(response.agenda, response.digest)
    })
  }
});

//
// Show/hide seen items
//
var ShowSeen = React.createClass({
  displayName: "ShowSeen",

  getInitialState: function() {
    return {label: "show seen"}
  },

  render: function() {
    return React.createElement(
      "button",
      {className: "btn btn-primary", onClick: this.click},
      this.state.label
    )
  },

  componentWillReceiveProps: function($$props) {
    if (Main.view && !Main.view.showseen()) {
      this.setState({label: "hide seen"})
    } else {
      this.setState({label: "show seen"})
    }
  },

  click: function(event) {
    Main.view.toggleseen();
    this.componentWillReceiveProps(this.props)
  }
});

//
// Timestamp start/stop of meeting
//
var Timestamp = React.createClass({
  displayName: "Timestamp",

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn btn-primary",
        onClick: this.click,
        disabled: this.state.disabled
      },

      "timestamp"
    )
  },

  click: function(event) {
    var self = this;

    var data = {
      agenda: Agenda.file,
      title: this.props.item.title,
      action: "timestamp"
    };

    this.setState({disabled: true});

    post("minute", data, function(minutes) {
      self.setState({disabled: false});
      Minutes.load(minutes)
    })
  }
});

var Vote = React.createClass({
  displayName: "Vote",

  statics: {button: {
    text: "vote",
    class: "btn_primary",
    data_toggle: "modal",
    data_target: "#vote-form"
  }},

  getInitialState: function() {
    return {disabled: false}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [
        ModalDialog,
        {className: "wide-form", id: "vote-form", color: "commented"}
      ];

      $_.push(React.createElement("h4", {className: "commented"}, "Vote"));

      $_.push(React.createElement(
        "p",
        null,

        React.createElement(
          "span",
          null,
          self.state.votetype + " vote on the matter of "
        ),

        React.createElement(
          "em",
          null,
          self.props.item.fulltitle.replace(/^Resolution to/, "")
        )
      ));

      $_.push(React.createElement("pre", null, self.state.directors));

      $_.push(React.createElement("textarea", {
        id: "vote-text",
        rows: 4,
        placeholder: "minutes",
        value: self.state.draft,

        onChange: function(event) {
          self.setState({draft: event.target.value})
        }
      }));

      $_.push(React.createElement(
        "button",

        {
          className: "btn-default",
          type: "button",
          "data-dismiss": "modal",

          onClick: function() {
            self.setState({draft: self.state.base})
          }
        },

        "Cancel"
      ));

      if (self.state.base) {
        $_.push(React.createElement(
          "button",
          {className: "btn-warning", type: "button", onClick: self.save},
          "Delete"
        ))
      };

      $_.push(React.createElement(
        "button",

        {
          className: "btn-primary",
          type: "button",
          onClick: self.save,
          disabled: self.state.draft == self.state.base
        },

        "Save"
      ));

      $_.push(React.createElement(
        "button",

        {
          className: "btn-warning",
          type: "button",
          onClick: self.save,
          disabled: self.state.draft != ""
        },

        "Tabled"
      ));

      $_.push(React.createElement(
        "button",

        {
          className: "btn-success",
          type: "button",
          onClick: self.save,
          disabled: self.state.draft != ""
        },

        "Unanimous"
      ));

      return $_
    }())
  },

  componentWillMount: function() {
    this.setup(this.props.item)
  },

  componentWillReceiveProps: function(newprops) {
    if (newprops.item.href != this.props.item.href) this.setup(newprops.item)
  },

  // reset base, draft minutes, directors present, and vote type
  setup: function(item) {
    var $directors = Minutes.directors_present;

    // alternate forward/reverse roll calls based on month and attachment
    var month = new Date(Date.parse(Agenda.date)).getMonth();
    var attach = item.attach.charCodeAt(1);

    if ((month + attach) % 2 == 0) {
      this.setState({votetype: "Roll call"})
    } else {
      this.setState({votetype: "Reverse roll call"});
      $directors = $directors.split("\n").reverse().join("\n")
    };

    this.setState({
      base: Minutes.get(item.title) || "",
      draft: Minutes.get(item.title) || "",
      directors: $directors
    })
  },

  // post vote results
  save: function(event) {
    var self = this;
    var text;

    switch (event.target.textContent) {
    case "Save":
      text = this.state.draft;
      break;

    case "Delete":
      text = "";
      break;

    case "Tabled":
      text = "tabled";
      break;

    case "Unanimous":
      text = "unanimous"
    };

    var data = {
      agenda: Agenda.file,
      title: this.props.item.title,
      text: text
    };

    this.setState({disabled: true});

    post("minute", data, function(minutes) {
      Minutes.load(minutes);
      self.setup(self.props.item);
      self.setState({disabled: false});
      jQuery("#vote-form").modal("hide");
      document.body.classList.remove("modal-open")
    })
  }
});

//
// Send email
//
var Email = React.createClass({
  displayName: "Email",

  render: function() {
    return React.createElement(
      "button",

      {
        className: "btn " + (this.mailto_class() || ""),
        onClick: this.launch_email_client
      },

      "send email"
    )
  },

  // render 'send email' as a primary button if the viewer is the shepherd for
  // the report, otherwise render the text as a simple link.
  mailto_class: function() {
    if (Server.firstname && this.props.item.shepherd && Server.firstname.substring(
      0,
      this.props.item.shepherd.toLowerCase().length
    ) == this.props.item.shepherd.toLowerCase()) {
      return "btn-primary"
    } else {
      return "btn-link"
    }
  },

  // launch email client, pre-filling the destination, subject, and body
  launch_email_client: function() {
    var destination = ("mailto:" + this.props.item.chair_email) + ("?cc=private@" + this.props.item.mail_list + ".apache.org,board@apache.org");
    var subject, body;

    if (this.props.item.missing) {
      subject = "Missing " + this.props.item.title + " Board Report";
      body = ("Dear " + this.props.item.owner + ",\n\nThe board report for ") + (this.props.item.title + " has not yet been submitted for this ") + "month's board meeting. If you're unable to get " + "it in by twenty-four hours before meeting time, " + "please plan to report next month.\n\nThanks,\n\n " + (Server.username + "\n\n") + "(on behalf of the ASF Board)"
    } else {
      subject = this.props.item.title + " Board Report";
      body = this.props.item.comments
    };

    window.location = destination + ("&subject=" + encodeURIComponent(subject)) + ("&body=" + encodeURIComponent(body))
  }
});

//
// Display information associated with an agenda item:
//   - special notes
//   - minutes
//   - posted reports
//   - action items
//   - posted comments
//   - pending comments
//   - historical comments
//
// Note: if AdditionalInfo is included multiple times in a page, set
//       prefix to true (or a string) to ensure rendered id attributes
//       are unique.
//
var AdditionalInfo = React.createClass({
  displayName: "AdditionalInfo",

  getInitialState: function() {
    return {}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", null];

      // special notes
      if (self.props.item.notes) {
        $_.push(React.createElement(
          "p",
          {className: "notes"},
          self.props.item.notes
        ))
      };

      // minutes
      var minutes = Minutes.get(self.props.item.title);

      if (minutes) {
        $_.push(React.createElement(
          "h4",
          {id: self.state.prefix + "minutes"},
          "Minutes"
        ));

        $_.push(React.createElement("pre", {className: "comment"}, minutes))
      };

      // posted reports
      var posted;

      if (self.props.item.missing) {
        posted = Posted.get(self.props.item.title);

        if (posted.length != 0) {
          $_.push(React.createElement(
            "h4",
            {id: self.state.prefix + "posted"},
            "Posted reports"
          ));

          $_.push(React.createElement.apply(React, function() {
            var $_ = ["ul", null];

            posted.forEach(function(post) {
              $_.push(React.createElement(
                "li",
                null,
                React.createElement("a", {href: post.link}, post.subject)
              ))
            });

            return $_
          }()))
        }
      };

      // action items
      if (self.props.item.title != "Action Items" && self.props.item.actions.length != 0) {
        $_.push(React.createElement(
          "h4",
          {id: self.state.prefix + "actions"},

          React.createElement(
            Link,
            {text: "Action Items", href: "Action-Items"}
          )
        ));

        $_.push(React.createElement(
          ActionItems,
          {item: self.props.item, filter: {pmc: self.props.item.title}}
        ))
      };

      if (self.props.item.special_orders.length != 0) {
        $_.push(React.createElement(
          "h4",
          {id: self.state.prefix + "orders"},
          "Special Orders"
        ));

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["ul", null];

          self.props.item.special_orders.forEach(function(resolution) {
            $_.push(React.createElement("li", null, React.createElement(
              Link,
              {text: resolution.title, href: resolution.href}
            )))
          });

          return $_
        }()))
      };

      // posted comments
      var history = HistoricalComments.find(self.props.item.title);

      if (self.props.item.comments.length != 0 || (history && !self.state.prefix)) {
        $_.push(React.createElement(
          "h4",
          {id: self.state.prefix + "comments"},
          "Comments"
        ));

        self.props.item.comments.forEach(function(comment) {
          $_.push(React.createElement(
            "pre",
            {className: "comment"},
            React.createElement(Text, {raw: comment, filters: [hotlink]})
          ))
        });

        // pending comments
        if (self.props.item.pending) {
          $_.push(React.createElement(
            "h5",
            {id: self.state.prefix + "pending"},
            "Pending Comment"
          ));

          $_.push(React.createElement(
            "pre",
            {className: "comment"},
            Flow.comment(self.props.item.pending, Pending.initials)
          ))
        };

        // historical comments
        if (history && !self.state.prefix) {
          for (var date in history) {
            if (Agenda.file == ("board_agenda_" + date + ".txt")) continue;

            $_.push(React.createElement.apply(React, function() {
              var $_ = ["h5", {className: "history"}];
              $_.push(React.createElement("span", null, "• "));

              $_.push(React.createElement(
                "a",
                {href: HistoricalComments.link(date, self.props.item.title)},
                date.replace(/_/g, "-")
              ));

              $_.push(React.createElement("span", null, ": "));

              // link to mail archive for feedback thread
              var dfr, dto;

              if (date > "2016_04") {
                // compute date range: from date of that meeting to now
                dfr = date.replace(/_/g, "-");
                dto = new Date(Date.now()).toISOString().slice(0, 10);

                $_.push(React.createElement(
                  "a",
                  {href: "https://lists.apache.org/list.html?board@apache.org&" + ("d=dfr=" + dfr + "|dto=" + dto + "&header_subject=") + ("'Board%20feedback%20on%20" + dfr + "%20" + self.props.item.title + "%20report'")},
                  "(thread)"
                ))
              };

              return $_
            }()));

            splitComments(history[date]).forEach(function(comment) {
              $_.push(React.createElement(
                "pre",
                {className: "comment"},
                React.createElement(Text, {raw: comment, filters: [hotlink]})
              ))
            })
          }
        }
      } else if (self.props.item.pending) {
        $_.push(React.createElement(
          "h4",
          {id: self.state.prefix + "pending"},
          "Pending Comment"
        ));

        $_.push(React.createElement(
          "pre",
          {className: "comment"},
          Flow.comment(self.props.item.pending, Pending.initials)
        ))
      };

      return $_
    }())
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  // determine prefix (if any)
  componentWillReceiveProps: function($$props) {
    if ($$props.prefix == true) {
      this.setState({prefix: $$props.item.title.toLowerCase() + "-"})
    } else if ($$props.prefix) {
      this.setState({prefix: $$props.prefix})
    } else {
      this.setState({prefix: ""})
    }
  }
});

//
// Replacement for 'a' element which handles clicks events that can be
// processed locally by calling Main.navigate.
//
var Link = React.createClass({
  displayName: "Link",

  getInitialState: function() {
    return {attrs: {}}
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props);
    this.state.attrs.onClick = this.click
  },

  componentWillReceiveProps: function(props) {
    this.setState({text: props.text});

    for (var attr in props) {
      if (!props[attr]) continue;
      if (attr != "text") this.state.attrs[attr] = props[attr]
    };

    if (props.href) {
      this.setState({element: "a"});

      this.state.attrs.href = props.href.replace(
        new RegExp("(^|/)\\w+/\\.\\.(/|$)", "g"),
        "$1"
      )
    } else {
      this.setState({element: "span"})
    }
  },

  render: function() {
    return React.createElement(
      this.state.element,
      this.state.attrs,
      this.state.text
    )
  },

  click: function(event) {
    if (event.ctrlKey || event.shiftKey || event.metaKey) return;
    var href = event.target.getAttribute("href");

    if (new RegExp("^(\\.|cache/.*|(flagged/|(shepherd/)?(queue/)?)[-\\w]+)$").test(href)) {
      event.stopPropagation();
      event.preventDefault();
      Main.navigate(href);
      return false
    }
  }
});

//
// Bootstrap modal dialogs are great, but they require a lot of boilerplate.
// This component provides the boiler plate so that other form components
// don't have to.  The elements provided by the calling component are
// distributed to header, body, and footer sections.
//
var ModalDialog = React.createClass({
  displayName: "ModalDialog",

  getInitialState: function() {
    return {header: [], body: [], footer: []}
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  componentWillReceiveProps: function($$props) {
    var self = this;
    this.state.header.length = 0;
    this.state.body.length = 0;
    this.state.footer.length = 0;

    $$props.children.forEach(function(child) {
      var label, props;

      if (child.type == "h4") {
        // place h4 elements into the header, adding a modal-title class
        child = self.addClass(child, "modal-title");
        self.state.header.push(child);
        ModalDialog.h4 = child
      } else if (child.type == "button") {
        // place button elements into the footer, adding a btn class
        child = self.addClass(child, "btn");
        self.state.footer.push(child)
      } else if (child.type == "input" || child.type == "textarea") {
        // wrap input and textarea elements in a form-control, 
        // add label if present
        child = self.addClass(child, "form-control");
        label = null;

        if (child.props.label && child.props.id) {
          props = {htmlFor: child.props.id};

          if (child.props.type == "checkbox") {
            props.className = "checkbox";
            label = React.createElement("label", props, child, child.props.label);
            delete child.props.label;
            child = null
          } else {
            label = React.createElement("label", props, child.props.label);
            child = React.cloneElement(child, {label: null})
          }
        };

        self.state.body.push(React.createElement(
          "div",
          {className: "form-group"},
          label,
          child
        ))
      } else {
        // place all other elements into the body
        self.state.body.push(child)
      }
    })
  },

  render: function() {
    return React.createElement(
      "div",

      {
        className: "modal fade " + (this.props.className || ""),
        id: this.props.id
      },

      React.createElement(
        "div",
        {className: "modal-dialog"},

        React.createElement(
          "div",
          {className: "modal-content"},

          React.createElement.apply(React, [
            "div",
            {className: "modal-header " + (this.props.color || "")},

            React.createElement(
              "button",
              {className: "close", type: "button", "data-dismiss": "modal"},
              "×"
            )
          ].concat(this.state.header)),

          React.createElement.apply(
            React,
            ["div", {className: "modal-body"}].concat(this.state.body)
          ),

          React.createElement.apply(
            React,
            ["div", {className: "modal-footer " + (this.props.color || "")}].concat(this.state.footer)
          )
        )
      )
    )
  },

  // helper method: add a class to an element, returning new element
  addClass: function(element, name) {
    if (!element.props.className) {
      element = React.cloneElement(element, {className: name})
    } else if (element.props.className.split(" ").indexOf(name) == -1) {
      element = React.cloneElement(
        element,
        {className: element.props.className + (" " + name)}
      )
    };

    return element
  }
});

//
// Escape text for inclusion in HTML; optionally apply filters
//
var Text = React.createClass({
  displayName: "Text",

  getInitialState: function() {
    return {}
  },

  componentWillMount: function() {
    this.componentWillReceiveProps(this.props)
  },

  componentWillReceiveProps: function($$props) {
    var self = this;
    var $text = htmlEscape($$props.raw || "");

    if ($$props.filters) {
      $$props.filters.forEach(function(filter) {
        self.setState({text: $text = filter($text)})
      })
    };

    this.setState({text: $text})
  },

  render: function() {
    return React.createElement(
      "span",
      {dangerouslySetInnerHTML: {__html: this.state.text}}
    )
  }
});

var Info = React.createClass({
  displayName: "Info",

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = [
        "dl",
        {className: "dl-horizontal " + (self.props.position || "")}
      ];

      $_.push(React.createElement("dt", null, "Attach"));
      $_.push(React.createElement("dd", null, self.props.item.attach));

      if (self.props.item.owner) {
        $_.push(React.createElement("dt", null, "Author"));
        $_.push(React.createElement("dd", null, self.props.item.owner))
      };

      if (self.props.item.shepherd) {
        $_.push(React.createElement("dt", null, "Shepherd"));

        $_.push(React.createElement.apply(React, function() {
          var $_ = ["dd", null];

          if (self.props.item.shepherd) {
            $_.push(React.createElement(Link, {
              text: self.props.item.shepherd,
              href: "shepherd/" + self.props.item.shepherd.split(" ")[0]
            }))
          };

          return $_
        }()))
      };

      if (self.props.item.flagged_by && self.props.item.flagged_by.length != 0) {
        $_.push(React.createElement("dt", null, "Flagged By"));

        $_.push(React.createElement(
          "dd",
          null,
          self.props.item.flagged_by.join(", ")
        ))
      };

      if (self.props.item.approved && self.props.item.approved.length != 0) {
        $_.push(React.createElement("dt", null, "Approved By"));

        $_.push(React.createElement(
          "dd",
          null,
          self.props.item.approved.join(", ")
        ))
      };

      if (self.props.item.roster || self.props.item.prior_reports || self.props.item.stats) {
        $_.push(React.createElement("dt", null, "Links"));

        if (self.props.item.roster) {
          $_.push(React.createElement(
            "dd",
            null,
            React.createElement("a", {href: self.props.item.roster}, "Roster")
          ))
        };

        if (self.props.item.prior_reports) {
          $_.push(React.createElement("dd", null, React.createElement(
            "a",
            {href: self.props.item.prior_reports},
            "Prior Reports"
          )))
        };

        if (self.props.item.stats) {
          $_.push(React.createElement(
            "dd",
            null,
            React.createElement("a", {href: self.props.item.stats}, "Statistics")
          ))
        }
      };

      return $_
    }())
  }
});

//
// Determine status of podling name
//
var PodlingNameSearch = React.createClass({
  displayName: "PodlingNameSearch",

  getInitialState: function() {
    return {}
  },

  render: function() {
    var self = this;

    return React.createElement.apply(React, function() {
      var $_ = ["span", {className: "pns", title: "podling name search"}];

      if (Server.podlingnamesearch) {
        if (!self.state.results) {
          $_.push(React.createElement(
            "abbr",
            {title: "No PODLINGNAMESEARCH found"},
            "✘"
          ))
        } else if (self.state.results.resolution == "Fixed") {
          $_.push(React.createElement(
            "a",
            {href: "https://issues.apache.org/jira/browse/" + self.state.results.issue},
            "✔"
          ))
        } else {
          $_.push(React.createElement(
            "a",
            {href: "https://issues.apache.org/jira/browse/" + self.state.results.issue},
            "﹖"
          ))
        }
      };

      return $_
    }())
  },

  // initial mount: fetch podlingnamesearch data unless already downloaded
  componentDidMount: function() {
    var self = this;

    if (Server.podlingnamesearch) {
      this.check(this.props)
    } else {
      retrieve("podlingnamesearch", "json", function(results) {
        Server.podlingnamesearch = results;
        self.check(self.props)
      })
    }
  },

  // when properties (in particular: title) changes, lookup name again
  componentWillReceiveProps: function(newprops) {
    this.check(newprops)
  },

  // lookup name in the establish resolution against the podlingnamesearches
  check: function(props) {
    this.setState({results: null});
    var name = (props.item.title.match(/Establish (.*)/) || [])[1];

    // if full title contains a name in parenthesis, check for that name too
    var altname = (props.item.fulltitle.match(/\((.*?)\)/) || [])[1];

    if (name && Server.podlingnamesearch) {
      for (var podling in Server.podlingnamesearch) {
        if (name == podling) {
          this.setState({results: Server.podlingnamesearch[name]})
        } else if (altname == podling) {
          this.setState({results: Server.podlingnamesearch[altname]})
        }
      }
    }
  }
});

//
// Motivation: browsers limit the number of open web socket connections to any
// one host to somewhere between 6 and 250, making it impractical to have one
// Web Socket per tab.
//
// The solution below uses localStorage to communicate between tabs, with
// the majority of logic involved with the "election" of a master.  This
// enables a single open connection to service all tabs open by a browser.
//
// Alternatives include: 
//
// * Replacing localStorage with Service Workers.  This would be much cleaner,
//   unfortunately Service Workers aren't widely deployed yet.  Sadly, the
//   state isn't much better for Shared Web Workers.
//
//##
//
// Class variables:
// * prefix:    application prefix for localStorage variables (which are
//              shared across the domain).
// * timestamp: unique identifier for each window/tab 
// * master:    identifier of the current master
// * ondeck:    identifier of the next in line to assume the role of master
//
function Events() {};
Events._subscriptions = {};
Events._socket = null;

Events.subscribe = function(event, block) {
  Events._subscriptions[event] = Events._subscriptions[event] || [];
  Events._subscriptions[event].push(block)
};

Events.monitor = function() {
  var self = this;
  Events._prefix = JSONStorage.prefix;

  // pick something unique to identify this tab/window
  Events._timestamp = new Date().getTime() + Math.random();
  this.log("Events id: " + Events._timestamp);

  // determine the current master (if any)
  Events._master = localStorage.getItem(Events._prefix + "-master");
  this.log("Events.master: " + Events._master);

  // register as a potential candidate for master
  localStorage.setItem(
    Events._prefix + "-ondeck",
    Events._ondeck = Events._timestamp
  );

  // relinquish roles on exit
  window.addEventListener("unload", function(event) {
    if (Events._master == Events._timestamp) {
      localStorage.removeItem(Events._prefix + "-master")
    };

    if (Events._ondeck == Events._timestamp) {
      localStorage.removeItem(Events._prefix + "-ondeck")
    }
  });

  // watch for changes
  window.addEventListener("storage", function(event) {
    // update tracking variables
    if (event.key == (Events._prefix + "-master")) {
      Events._master = event.newValue;
      self.log("Events.master: " + Events._master);
      self.negotiate()
    } else if (event.key == (Events._prefix + "-ondeck")) {
      Events._ondeck = event.newValue;
      self.log("Events.ondeck: " + Events._ondeck);
      self.negotiate()
    } else if (event.key == (Events._prefix + "-event")) {
      self.dispatch(event.newValue)
    }
  });

  // dead man's switch: remove master when timestamp isn't updated
  if (Events._master && Events._timestamp - localStorage.getItem(Events._prefix + "-timestamp") > 30000) {
    this.log("Events: Removing previous master");
    Events._master = localStorage.removeItem(Events._prefix + "-master")
  };

  // negotiate for the role of master
  this.negotiate()
};

// negotiate changes in masters
Events.negotiate = function() {
  var self = this;
  var options, request;

  if (Events._master == null && Events._ondeck == Events._timestamp) {
    this.log("Events: Assuming the role of master");

    localStorage.setItem(
      Events._prefix + "-timestamp",
      new Date().getTime()
    );

    localStorage.setItem(
      Events._prefix + "-master",
      Events._master = Events._timestamp
    );

    Events._ondeck = localStorage.removeItem(Events._prefix + "-ondeck");

    if (Server.session) {
      this.master()
    } else {
      options = {credentials: "include"};
      request = new Request("../session.json", options);

      fetch(request).then(function(response) {
        response.json().then(function(json) {
          Server.session = json.session;
          self.master()
        })
      })
    }
  } else if (Events._ondeck == null && Events._master != Events._timestamp && !localStorage.getItem(Events._prefix + "-ondeck")) {
    localStorage.setItem(
      Events._prefix + "-ondeck",
      Events._ondeck = Events._timestamp
    )
  }
};

// master logic
Events.master = function() {
  var self = this;
  this.connectToServer();

  // proof of life; maintain connection to the server
  setInterval(
    function() {
      localStorage.setItem(
        Events._prefix + "-timestamp",
        new Date().getTime()
      );

      self.connectToServer()
    },

    25000
  );

  // close connection on exit
  window.addEventListener("unload", function(event) {
    if (Events._socket) Events._socket.close()
  })
};

// establish a connection to the server
Events.connectToServer = function() {
  var self = this;

  try {
    if (Events._socket) return;
    var socket_url = window.location.protocol.replace("http", "ws") + "//" + window.location.hostname + ":34234/";
    Events._socket = new WebSocket(Server.websocket);

    Events._socket.onopen = function(event) {
      Events._socket.send("session: " + Server.session + "\n\n");
      self.log("WebSocket connection established")
    };

    Events._socket.onmessage = function(event) {
      localStorage.setItem(Events._prefix + "-event", event.data);
      self.dispatch(event.data)
    };

    Events._socket.onerror = function(event) {
      if (Events._socket) self.log("WebSocket connection terminated");
      Events._socket = null
    };

    Events._socket.onclose = function(event) {
      if (Events._socket) self.log("WebSocket connection terminated");
      Events._socket = null
    }
  } catch (e) {
    this.log(e)
  }
};

// dispatch logic (common to all tabs)
Events.dispatch = function(data) {
  var self = this;
  var message = JSON.parse(data);
  this.log(message);
  var options, request;

  if (message.type == "unauthorized") {
    options = {credentials: "include"};
    request = new Request("../session.json", options);

    fetch(request).then(function(response) {
      response.json().then(function(json) {
        self.log(json);
        Server.session = json.session
      })
    })
  } else if (Events._subscriptions[message.type]) {
    Events._subscriptions[message.type].forEach(function(sub) {
      sub(message)
    })
  };

  Main.refresh()
};

// log messages (unless running tests)
Events.log = function(message) {
  if (!navigator.userAgent || navigator.userAgent.indexOf("PhantomJS") != -1) {
    return
  };

  console.log(message)
};

Object.defineProperty(
  Events,
  "prefix",

  {enumerable: true, configurable: true, get: function() {
    if (Events._prefix) return Events._prefix;

    // determine localStorage variable prefix based on url up to the date
    var base = document.getElementsByTagName("base")[0].href;
    var origin = location.origin;

    if (!origin) {
      origin = window.location.protocol + "//" + window.location.hostname + ((window.location.port ? ":" + window.location.port : ""))
    };

    Events._prefix = base.slice(origin.length, base.length).replace(
      new RegExp("/\\d{4}-\\d\\d-\\d\\d/.*"),
      ""
    ).replace(/^\W+|\W+$/g, "").replace(/\W+/g, "_") || location.port
  }}
);

//
// A cache of agenda related pages, useful for:
//
//  1) quick loading of possibly stale data, which will be updated with
//     current information as it becomes available.
//
//  2) offline access to the agenda tool
//
function PageCache() {};

// is page cache available?
Object.defineProperty(
  PageCache,
  "enabled",

  {enumerable: true, configurable: true, get: function() {
    if (location.protocol != "https:" && location.hostname != "localhost") {
      return false
    };

    // disable service workers for the production server(s) for now.  See:
    // https://lists.w3.org/Archives/Public/public-webapps/2016JulSep/0016.html
    if (/^whimsy.*\.apache\.org$/.test(location.hostname)) {
      if (location.hostname.indexOf("-test") == -1) return false
    };

    return typeof ServiceWorker !== 'undefined' && typeof navigator !== 'undefined'
  }}
);

// registration and related startup actions
PageCache.register = function() {
  // preload page cache once page finishes loading
  window.addEventListener("load", function(event) {
    PageCache.preload()
  });

  // register service worker
  var scope = new URL("..", document.getElementsByTagName("base")[0].href);
  navigator.serviceWorker.register(scope + "sw.js", scope)
};

// aggressively attempt to preload pages directly used by the agenda pages
// into the appropriate cache.
PageCache.preload = function() {
  if (!PageCache.enabled) return;
  var request = new Request("bootstrap.html", {credentials: "include"});

  fetch(request).then(function(response) {
    // add/update bootstrap.html in the cache
    caches.open("board/agenda").then(function(cache) {
      cache.put(request, response.clone())
    })
  })
};

//
// This is the client model for an entire Agenda.  Class methods refer to
// the agenda as a whole.  Instance methods refer to an individual agenda
// item.
//
// initialize an entry by copying each JSON property to a class instance
// variable.
function Agenda(entry) {
  for (var name in entry) {
    this["_" + name] = entry[name]
  }
};

Agenda._index = [];
Agenda._etag = null;
Agenda._digest = null;

// (re)-load an agenda, creating instances for each item, and linking
// each instance to their next and previous items.
Agenda.load = function(list, digest) {
  if (!list) return;
  Agenda._digest = digest;
  Agenda._index.length = 0;
  var prev = null;

  list.forEach(function(item) {
    item = new Agenda(item);
    item.prev = prev;
    if (prev) prev.next = item;
    prev = item;
    Agenda._index.push(item)
  });

  // remove president attachments from the normal flow
  Agenda._index.forEach(function(pres) {
    match = pres.title == "President" && pres.text && pres.text.match(/Additionally, please see Attachments (\d) through (\d)/);
    if (!match) return;
    var first;
    var last;
    first = last = null;

    Agenda._index.forEach(function(item) {
      if (item.attach == match[1]) first = item;
      if (first && !last) item._shepherd = item._shepherd || pres.shepherd;
      if (item.attach == match[2]) last = item
    });

    if (first && last) {
      first.prev.next = last.next;
      last.next.prev = first.prev;
      last.next.index = first.index;
      first.index = null;
      last.next = pres;
      first.prev = pres
    }
  });

  Agenda._date = (new Date(Agenda._index[0].timestamp).toISOString().match(/(.*?)T/) || [])[1];
  Main.refresh();
  return Agenda._index
};

// fetch agenda if etag is not supplied
Agenda.fetch = function(etag, digest) {
  var loaded, options, request, xhr;

  if (etag) {
    Agenda._etag = etag
  } else if (digest != Agenda._digest || !Agenda._etag) {
    if (PageCache.enabled) {
      loaded = false;

      // if bootstrapping and cache is available, load it
      if (!digest) {
        caches.open("board/agenda").then(function(cache) {
          cache.match("../" + Agenda._date + ".json").then(function(response) {
            if (response) {
              response.json().then(function(json) {
                if (!loaded) Agenda.load(json);
                Main.refresh()
              })
            }
          })
        })
      };

      // set fetch options: credentials and etag
      options = {credentials: "include"};
      if (Agenda._etag) options["headers"] = {"If-None-Match": Agenda._etag};
      request = new Request("../" + Agenda._date + ".json", options);

      // perform fetch
      fetch(request).then(function(response) {
        if (response) {
          loaded = true;

          // load response into the agenda
          response.clone().json().then(function(json) {
            Agenda._etag = response.headers.get("etag");
            Agenda.load(json);
            Main.refresh()
          });

          // save response in the cache
          caches.open("board/agenda").then(function(cache) {
            cache.put(request, response)
          })
        }
      })
    } else {
      // AJAX fallback
      xhr = new XMLHttpRequest();
      xhr.open("GET", "../" + Agenda._date + ".json", true);
      if (Agenda._etag) xhr.setRequestHeader("If-None-Match", Agenda._etag);
      xhr.responseType = "text";

      xhr.onreadystatechange = function() {
        if (xhr.readyState == 4 && xhr.status == 200 && xhr.responseText != "") {
          Agenda._etag = xhr.getResponseHeader("ETag");
          Agenda.load(JSON.parse(xhr.responseText));
          Main.refresh()
        }
      };

      xhr.send()
    }
  };

  Agenda._digest = digest
};

// return the entire agenda
Object.defineProperty(
  Agenda,
  "index",

  {enumerable: true, configurable: true, get: function() {
    return Agenda._index
  }}
);

// find an agenda item by path name
Agenda.find = function(path) {
  var result = null;

  Agenda._index.forEach(function(item) {
    if (item.href == path) result = item
  });

  return result
};

Agenda.prototype = {
  // provide read-only access to a number of properties 
  get attach() {
    return this._attach
  },

  get title() {
    return this._title
  },

  get owner() {
    return this._owner
  },

  get shepherd() {
    return this._shepherd
  },

  get index() {
    return this._index
  },

  get timestamp() {
    return this._timestamp
  },

  get digest() {
    return this._digest
  },

  get approved() {
    return this._approved
  },

  get roster() {
    return this._roster
  },

  get prior_reports() {
    return this._prior_reports
  },

  get stats() {
    return this._stats
  },

  get people() {
    return this._people
  },

  get notes() {
    return this._notes
  },

  get chair_email() {
    return this._chair_email
  },

  get mail_list() {
    return this._mail_list
  },

  get warnings() {
    return this._warnings
  },

  get flagged_by() {
    return this._flagged_by
  },

  get fulltitle() {
    return this._fulltitle || this._title
  },

  // override missing if minutes aren't present
  get missing() {
    if (this._missing) {
      return true
    } else if (/^3\w$/.test(this._attach)) {
      if (Server.drafts.indexOf((this._text.match(/board_minutes_\w+.txt/) || [])[0]) != -1) {
        return false
      } else {
        return true
      }
    } else {
      return false
    }
  },

  // compute href by taking the title and replacing all non alphanumeric
  // characters with dashes
  get href() {
    return this._title.replace(/[^a-zA-Z0-9]+/g, "-")
  },

  // return the text or report for the agenda item
  get text() {
    return this._text || this._report
  },

  // return comments as an array of individual comments
  get comments() {
    return splitComments(this._comments)
  },

  // item's comments excluding comments that have been seen before
  get unseen_comments() {
    var visible = [];
    var seen = Pending.seen[this._attach] || [];

    this.comments.forEach(function(comment) {
      if (seen.indexOf(comment) == -1) visible.push(comment)
    });

    return visible
  },

  // retrieve the pending comment (if any) associated with this agenda item
  get pending() {
    return Pending.comments[this._attach]
  },

  // retrieve the action items associated with this agenda item
  get actions() {
    var self = this;
    var item, list;

    if (this._title == "Action Items") {
      return this._actions
    } else {
      item = Agenda.find("Action-Items");
      list = [];

      if (item) {
        item.actions.forEach(function(action) {
          if (action.pmc == self._title) list.push(action)
        })
      };

      return list
    }
  },

  get special_orders() {
    var self = this;
    var items = [];

    if (/^[A-Z]+$/.test(this._attach)) {
      Agenda.index.forEach(function(item) {
        if (/^7/.test(item.attach) && item.roster == self._roster) items.push(item)
      })
    };

    return items
  },

  ready_for_review: function(initials) {
    return typeof this._approved !== 'undefined' && !this.missing && this._approved.indexOf(initials) == -1 && !(this._flagged_by && this._flagged_by.indexOf(initials) != -1)
  }
};

Object.defineProperties(Agenda, {
  // the default view to use for the agenda as a whole
  view: {enumerable: true, configurable: true, get: function() {
    return Index
  }},

  // buttons to show on the index page
  buttons: {enumerable: true, configurable: true, get: function() {
    var list = [{button: Refresh}];
    if (!Minutes.complete) list.push({form: Post, text: "add resolution"});

    if (Server.role == "secretary") {
      if (Server.drafts.indexOf(Agenda.file.replace("agenda", "minutes")) != -1) {
        list.push({form: PublishMinutes})
      } else if (Minutes.ready_to_post_draft) {
        list.push({form: DraftMinutes})
      }
    };

    return list
  }},

  // the default banner color to use for the agenda as a whole
  color: {enumerable: true, configurable: true, get: function() {
    return "blank"
  }},

  // the default title for the agenda as a whole
  date: {enumerable: true, configurable: true, get: function() {
    return Agenda._date
  }},

  title: {enumerable: true, configurable: true, get: function() {
    return Agenda._date
  }},

  // the file associated with this agenda
  file: {enumerable: true, configurable: true, get: function() {
    return "board_agenda_" + Agenda._date.replace(/\-/g, "_") + ".txt"
  }},

  // get the digest of the file associated with this agenda
  digest: {enumerable: true, configurable: true, get: function() {
    return Agenda._digest
  }},

  // previous link for the agenda index page
  prev: {enumerable: true, configurable: true, get: function() {
    var result = {title: "Help", href: "help"};

    Server.agendas.forEach(function(agenda) {
      var date = (agenda.match(/(\d+_\d+_\d+)/) || [])[1].replace(
        /_/g,
        "-"
      );

      if (date < Agenda._date && (result.title == "Help" || date > result.title)) {
        result = {title: date, href: "../" + date + "/"}
      }
    });

    return result
  }},

  // next link for the agenda index page
  next: {enumerable: true, configurable: true, get: function() {
    var result = {title: "Help", href: "help"};

    Server.agendas.forEach(function(agenda) {
      var date = (agenda.match(/(\d+_\d+_\d+)/) || [])[1].replace(
        /_/g,
        "-"
      );

      if (date > Agenda._date && (result.title == "Help" || date < result.title)) {
        result = {title: date, href: "../" + date + "/"}
      }
    });

    return result
  }},

  // find the shortest match for shepherd name (example: Rich)
  shepherd: {enumerable: true, configurable: true, get: function() {
    var shepherd = null;
    var firstname = Server.firstname.toLowerCase();

    Agenda.index.forEach(function(item) {
      if (item.shepherd && firstname.substring(
        0,
        item.shepherd.toLowerCase().length
      ) == item.shepherd.toLowerCase() && (!shepherd || item.shepherd.length < shepherd.lenth)) {
        shepherd = item.shepherd
      }
    });

    return shepherd
  }},

  // summary
  summary: {enumerable: true, configurable: true, get: function() {
    var results = [];

    // committee reports
    var count = 0;
    var link = null;

    Agenda.index.forEach(function(item) {
      if (/^[A-Z]+$/.test(item.attach)) {
        count++;
        link = link || item.href
      }
    });

    results.push({
      color: "available",
      count: count,
      href: link,
      text: "committee reports"
    });

    // special orders
    count = 0;
    link = null;

    Agenda.index.forEach(function(item) {
      if (/^7[A-Z]+$/.test(item.attach)) {
        count++;
        link = link || item.href
      }
    });

    results.push({
      color: "available",
      count: count,
      href: link,
      text: "special orders"
    });

    // awaiting preapprovals
    count = 0;

    Agenda.index.forEach(function(item) {
      if (item.color == "ready") count++
    });

    results.push({
      color: "ready",
      count: count,
      href: "queue",
      text: "awaiting preapprovals"
    });

    // flagged reports
    count = 0;

    Agenda.index.forEach(function(item) {
      if (item.flagged_by) count++
    });

    results.push({
      color: "commented",
      count: count,
      href: "flagged",
      text: "flagged reports"
    });

    // missing reports
    count = 0;

    Agenda.index.forEach(function(item) {
      if (item.missing) count++
    });

    results.push({
      color: "missing",
      count: count,
      href: "missing",
      text: "missing reports"
    });

    return results
  }}
});

Object.defineProperties(Agenda.prototype, {
  //
  // Methods on individual agenda items
  //
  // default view for an individual agenda item
  view: {enumerable: true, configurable: true, get: function() {
    if (this._title == "Action Items") {
      return (this._text || Minutes.started ? ActionItems : SelectActions)
    } else if (this._title == "Roll Call" && Server.role == "secretary") {
      return RollCall
    } else if (this._title == "Adjournment" && Server.role == "secretary") {
      return Adjournment
    } else {
      return Report
    }
  }},

  // buttons and forms to show with this report
  buttons: {enumerable: true, configurable: true, get: function() {
    var list = [];

    if (this._comments !== undefined && !Minutes.complete) {
      // some reports don't have comments
      if (this.pending) {
        list.push({form: AddComment, text: "edit comment"})
      } else {
        list.push({form: AddComment, text: "add comment"})
      }
    };

    if (this._title == "Roll Call") list.push({button: Attend});

    if (/^(\d|7?[A-Z]+|4[A-Z])$/.test(this._attach) && !Minutes.complete) {
      if (this.missing) {
        list.push({form: Post, text: "post report"})
      } else if (/^7\w/.test(this._attach)) {
        list.push({form: Post, text: "edit resolution"})
      } else {
        list.push({form: Post, text: "edit report"})
      }
    };

    if (Server.role == "director") {
      if (!this.missing && this._comments !== undefined && !Minutes.complete) {
        list.push({button: Approve})
      }
    } else if (Server.role == "secretary") {
      if (/^7\w/.test(this._attach)) {
        list.push({form: Vote})
      } else if (Minutes.get(this._title)) {
        list.push({form: AddMinutes, text: "edit minutes"})
      } else if (["Call to order", "Adjournment"].indexOf(this._title) != -1) {
        list.push({button: Timestamp})
      } else {
        list.push({form: AddMinutes, text: "add minutes"})
      };

      if (/^3\w/.test(this._attach)) {
        if (Minutes.get(this._title) == "approved" && Server.drafts.indexOf((this._text.match(/board_minutes_\w+\.txt/) || [])[0]) != -1) {
          list.push({form: PublishMinutes})
        }
      } else if (this._title == "Adjournment") {
        if (Minutes.ready_to_post_draft) list.push({form: DraftMinutes})
      }
    };

    return list
  }},

  // determine if this item is flagged, accounting for pending actions
  flagged: {enumerable: true, configurable: true, get: function() {
    if (Pending.flagged.indexOf(this._attach) != -1) return true;
    if (!this._flagged_by) return false;

    if (this._flagged_by.length == 1 && this._flagged_by[0] == Server.initials && Pending.unflagged.indexOf(this._attach) != -1) {
      return false
    };

    return this._flagged_by.length != 0
  }},

  // banner color for this agenda item
  color: {enumerable: true, configurable: true, get: function() {
    if (!this._title) {
      return "blank"
    } else if (this._warnings) {
      return "missing"
    } else if (this.missing) {
      return "missing"
    } else if (this._approved) {
      if (this.flagged) {
        return "commented"
      } else if (this._approved.length < 5) {
        return "ready"
      } else {
        return "reviewed"
      }
    } else if (this._text || this._report) {
      return "available"
    } else if (this._text === undefined) {
      return "missing"
    } else {
      return "reviewed"
    }
  }}
});

Events.subscribe("agenda", function(message) {
  if (message.file == Agenda.file) Agenda.fetch(null, message.digest)
});

Events.subscribe("server", function(message) {
  if (message.drafts) Server.drafts = message.drafts;
  if (message.agendas) Server.agendas = message.agendas
});

//
// This is the client model for draft Minutes.
//
function Minutes() {};
Minutes._list = {};

// (re)-load minutes
Minutes.load = function(list) {
  Minutes._list = {};

  if (list) {
    for (var title in list) {
      Minutes._list[title] = list[title]
    }
  };

  Minutes._list.attendance = Minutes._list.attendance || {}
};

// list of actions created during the meeting
Object.defineProperty(
  Minutes,
  "actions",

  {enumerable: true, configurable: true, get: function() {
    var actions = [];

    for (var title in Minutes._list) {
      var minutes = Minutes._list[title] + "\n\n";
      var pattern = /^(?:@|AI\s+)(\w+):?\s+([\s\S]*?)(\n\n|$)/g;
      var match = pattern.exec(minutes);

      while (match) {
        actions.push({
          owner: match[1],
          text: match[2],
          item: Agenda.find(title.replace(/\W/g, "-"))
        });

        match = pattern.exec(minutes)
      }
    };

    return actions
  }}
);

// fetch minutes for a given agenda item, by title
Minutes.get = function(title) {
  return Minutes._list[title]
};

Object.defineProperties(Minutes, {
  attendees: {enumerable: true, configurable: true, get: function() {
    return Minutes._list.attendance
  }},

  // return a list of actual or expected attendee names
  attendee_names: {
    enumerable: true,
    configurable: true,

    get: function() {
      var names = [];
      var attendance = Object.keys(Minutes._list.attendance);
      var rollcall, pattern;

      if (attendance.length == 0) {
        rollcall = Minutes.get("Roll Call") || Agenda.find("Roll-Call").text;
        pattern = /\n ( [a-z]*[A-Z][a-zA-Z]*\.?)+/g;

        while (match = pattern.exec(rollcall)) {
          var name = match[0].replace(/^\s+/, "").split(" ")[0];
          if (names.indexOf(name) == -1) names.push(name)
        }
      } else {
        attendance.forEach(function(name) {
          if (!Minutes._list.attendance[name].present) return;
          name = name.split(" ")[0];
          if (names.indexOf(name) == -1) names.push(name)
        })
      };

      return names.sort()
    }
  },

  // return a list of directors present
  directors_present: {
    enumerable: true,
    configurable: true,

    get: function() {
      var rollcall = Minutes.get("Roll Call") || Agenda.find("Roll-Call").text;

      return (rollcall.match(/Directors.*Present:\n\n((.*\n)*?)\n/) || [])[1].replace(
        /\n$/,
        ""
      )
    }
  },

  // determine if the meeting has started
  started: {enumerable: true, configurable: true, get: function() {
    return Minutes._list.started
  }},

  // determine if the meeting is over
  complete: {enumerable: true, configurable: true, get: function() {
    return Minutes._list.complete
  }},

  // determine if the draft is ready
  ready_to_post_draft: {
    enumerable: true,
    configurable: true,

    get: function() {
      return this.complete && Server.drafts.indexOf(Agenda.file.replace(
        "_agenda_",
        "_minutes_"
      )) == -1
    }
  }
});

Events.subscribe("minutes", function(message) {
  if (message.agenda == Agenda.file) Minutes.load(message.value)
});

function Chat() {};
Chat._log = [];
Chat._topic = {};
Chat.fetch_requested = false;
Chat.backlog_fetched = false;

// as it says: fetch backlog of chat messages from the server
Chat.fetch_backlog = function() {
  if (Chat.fetch_requested) return;

  retrieve(
    "chat/" + (Agenda.file.match(/\d[\d_]+/) || [])[0],
    "json",

    function(messages) {
      messages.forEach(function(message) {
        Chat.add(message)
      });

      Chat.backlog_fetched = true
    }
  );

  Chat.fetch_requested = true;
  this.countdown();
  setInterval(this.countdown, 30000)
};

// set topic to meeting status
Chat.countdown = function() {
  var status = Chat.status;
  if (status) Chat.setTopic({subtype: "status", user: "whimsy", text: status})
};

// replace topic locally
Chat.setTopic = function(entry) {
  if (Chat._topic.text == entry.text) return;

  Chat._log = Chat._log.filter(function(item) {
    return item.type != "topic"
  });

  entry.type = "topic";
  Chat._topic = entry;
  Chat.add(entry);
  if (entry.subtype == "status") Main.refresh()
};

// change topic globally
Chat.changeTopic = function(entry) {
  if (Chat._topic.text == entry.text) return;
  entry.type = "topic";
  entry.agenda = Agenda.file;
  post("message", entry, function(message) {Chat.setTopic(entry)})
};

// return the chat log
Object.defineProperty(
  Chat,
  "log",

  {enumerable: true, configurable: true, get: function() {
    return Chat._log
  }}
);

// add an entry to the chat log
Chat.add = function(entry) {
  entry.timestamp = entry.timestamp || new Date().getTime();

  if (Chat._log.length == 0 || Chat._log[Chat._log.length - 1].timestamp < entry.timestamp) {
    Chat._log.push(entry)
  } else {
    for (var i = 0; i < Chat._log.length; i++) {
      if (entry.timestamp <= Chat._log[i].timestamp) {
        if (entry.timestamp != Chat._log[i].timestamp || entry.text != Chat._log[i].text) {
          Chat._log.splice(i, 0, entry)
        };

        break
      }
    }
  }
};

// meeting status for countdown
Object.defineProperty(
  Chat,
  "status",

  {enumerable: true, configurable: true, get: function() {
    var diff = Agenda.find("Call-to-order").timestamp - new Date().getTime();

    if (Minutes.complete) {
      return "meeting has completed"
    } else if (Minutes.started) {
      return (Chat._topic.subtype == "status" ? Chat._topic.text : "meeting has started")
    } else if (diff > 86400000 * 3 / 2) {
      return "meeting will start in about " + Math.floor(diff / 86400000 + 0.5) + " days"
    } else if (diff > 3600000 * 3 / 2) {
      return "meeting will start in about " + Math.floor(diff / 3600000 + 0.5) + " hours"
    } else if (diff > 300000) {
      return "meeting will start in about " + Math.floor(diff / 300000 + 0.5) * 5 + " minutes"
    } else if (diff > 90000) {
      return "meeting will start in about " + Math.floor(diff / 60000 + 0.5) + " minutes"
    } else {
      return "meeting will start shortly"
    }
  }}
);

// subscriptions
Events.subscribe("chat", function(message) {
  if (message.agenda == Agenda.file) {
    delete message[agenda];
    Chat.add(message)
  }
});

Events.subscribe("info", function(message) {
  if (message.agenda == Agenda.file) {
    delete message[agenda];
    Chat.add(message)
  }
});

Events.subscribe("topic", function(message) {
  if (message.agenda == Agenda.file) Chat.setTopic(message)
});

Events.subscribe("arrive", function(message) {
  Server.online = message.present;

  Chat.add({
    type: "info",
    user: message.user,
    timestamp: message.timestamp,
    text: "joined the chat"
  })
});

Events.subscribe("depart", function(message) {
  Server.online = message.present;

  Chat.add({
    type: "info",
    user: message.user,
    timestamp: message.timestamp,
    text: "left the chat"
  })
});

//
// Fetch, retain, and query the list of JIRA projects
//
function JIRA() {};
JIRA._list = null;

JIRA.find = function(name) {
  if (JIRA._list) {
    return JIRA._list.indexOf(name) != -1
  } else {
    JIRA._list = [];
    JSONStorage.fetch("jira", function(list) {JIRA._list = list})
  }
};

//
// Provide a thin (and quite possibly unnecessary) interface to the
// Server.pending data structure.
//
function Pending() {};

Pending.load = function(value) {
  if (value) Server.pending = value;
  Main.refresh();
  return value
};

Object.defineProperties(Pending, {
  count: {enumerable: true, configurable: true, get: function() {
    return Object.keys(this.comments).length + Object.keys(this.approved).length + Object.keys(this.unapproved).length + Object.keys(this.flagged).length + Object.keys(this.unflagged).length + Object.keys(this.status).length
  }},

  comments: {enumerable: true, configurable: true, get: function() {
    return (Server.pending ? Server.pending.comments : [])
  }},

  approved: {enumerable: true, configurable: true, get: function() {
    return Server.pending.approved
  }},

  unapproved: {enumerable: true, configurable: true, get: function() {
    return Server.pending.unapproved
  }},

  flagged: {enumerable: true, configurable: true, get: function() {
    return Server.pending.flagged
  }},

  unflagged: {enumerable: true, configurable: true, get: function() {
    return Server.pending.unflagged
  }},

  seen: {enumerable: true, configurable: true, get: function() {
    return Server.pending.seen
  }},

  initials: {enumerable: true, configurable: true, get: function() {
    return Server.pending.initials || Server.initials
  }},

  status: {enumerable: true, configurable: true, get: function() {
    return Server.pending.status || []
  }}
});

// find a pending status update that matches a given action item
Pending.find_status = function(action) {
  var match = null;

  Pending.status.forEach(function(status) {
    var found = true;

    for (var name in action) {
      if (name != "status" && action[name] != status[name]) found = false
    };

    if (found) match = status
  });

  return match
};

Events.subscribe("pending", function(message) {
  Pending.load(message.value)
});

// Posted PMC reports - see https://whimsy.apache.org/board/posted-reports
function Posted() {};
Posted._list = [];
Posted._fetched = false;

Posted.get = function(title) {
  var results = [];

  // fetch list of reports on first reference
  if (!Posted._fetched) {
    Posted._list = [];

    JSONStorage.fetch("posted-reports", function(list) {
      Posted._list = list
    });

    Posted._fetched = true
  };

  // return list of matching reports
  Posted._list.forEach(function(entry) {
    if (entry.title == title) results.push(entry)
  });

  return results
};

//
// Fetch, retain, and query the list of historical comments
//
function HistoricalComments() {};
HistoricalComments._comments = null;

// find historical comments based on report title
HistoricalComments.find = function(title) {
  if (HistoricalComments._comments) {
    return HistoricalComments._comments[title]
  } else {
    HistoricalComments._comments = {};

    JSONStorage.fetch("historical-comments", function(comments) {
      HistoricalComments._comments = comments || {}
    })
  }
};

// find link for historical comments based on date and report title
HistoricalComments.link = function(date, title) {
  if (Server.agendas.indexOf("board_agenda_" + date + ".txt") != -1) {
    return "../" + date.replace(/_/g, "-") + "/" + title
  } else {
    return "../../minutes/" + title + ".html#minutes_" + date
  }
};

//
// Originally defined to simplify access to sessionStorage for JSON objects.
//
// Now expanded to include caching using fetch and the cache defined in
// the Service Workers specification (but without the user of SWs).
//
function JSONStorage() {};

// determine sessionStorage variable prefix based on url up to the date
Object.defineProperty(
  JSONStorage,
  "prefix",

  {enumerable: true, configurable: true, get: function() {
    if (JSONStorage._prefix) return JSONStorage._prefix;
    var base = document.getElementsByTagName("base")[0].href;
    var origin = location.origin;

    if (!origin) {
      origin = window.location.protocol + "//" + window.location.hostname + ((window.location.port ? ":" + window.location.port : ""))
    };

    JSONStorage._prefix = base.slice(origin.length, base.length).replace(
      new RegExp("/\\d{4}-\\d\\d-\\d\\d/.*"),
      ""
    ).replace(/^\W+|\W+$/g, "").replace(/\W+/g, "_") || location.port
  }}
);

// store an item, converting it to JSON
JSONStorage.put = function(name, value) {
  name = JSONStorage.prefix + "-" + name;

  try {
    sessionStorage.setItem(name, JSON.stringify(value))
  } catch (e) {

  };
  return value
};

// retrieve an item, converting it back to an object
JSONStorage.get = function(name) {
  if (typeof sessionStorage !== 'undefined') {
    name = JSONStorage.prefix + "-" + name;
    return JSON.parse(sessionStorage.getItem(name) || "null")
  }
};

// retrieve an cached object.  Note: block may be dispatched twice,
// once with slightly stale data and once with current data
//
// Note: caches only work currently on Firefox and Chrome.  All
// other browsers fall back to XMLHttpRequest (AJAX).
JSONStorage.fetch = function(name, block) {
  if (typeof fetch !== 'undefined' && typeof caches !== 'undefined' && (location.protocol == "https:" || location.hostname == "localhost")) {
    caches.open("board/agenda").then(function(cache) {
      var fetched = null;
      clock_counter++;

      // construct request
      var request = new Request("../json/" + name, {
        method: "get",
        credentials: "include",
        headers: {Accept: "application/json"}
      });

      // dispatch request
      fetch(request).then(function(response) {
        cache.put(request, response.clone());

        response.json().then(function(json) {
          if (!fetched || JSON.stringify(fetched) != JSON.stringify(json)) {
            if (!fetched) clock_counter--;
            fetched = json;
            if (json) block(json);
            Main.refresh()
          }
        })
      });

      // check cache
      cache.match("../json/" + name).then(function(response) {
        if (response && !fetched) {
          response.json().then(function(json) {
            clock_counter--;
            fetched = json;
            if (json) block(json);
            Main.refresh()
          })
        }
      })
    })
  } else if (typeof XMLHttpRequest !== 'undefined') {
    // retrieve from the network only
    retrieve(name, "json", block)
  }
}