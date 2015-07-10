// Copyright (c) 2015 takumakei
// Distributed under MIT license.
// See file LICENSE for detail.

#include <getopt.h>
#include <libgen.h>

#include <iomanip>
#include <iostream>
#include <list>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <unordered_set>

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

char const* const ENV_OSX_DICTIONARY = "OSX_DICTIONARY";

extern "C" {
  NSArray *DCSGetActiveDictionaries();
  NSArray *DCSCopyAvailableDictionaries();
  NSString *DCSDictionaryGetName(DCSDictionaryRef dictID);
  NSString *DCSDictionaryGetShortName(DCSDictionaryRef dictID);
}

using namespace std;

template<class Itr>
Itr stable_unique(Itr itr, Itr end) {
  using A = typename Itr::value_type;
  using std::swap;
  unordered_set<A> s;
  for_each(itr, end, [&](A& a) { if (s.insert(a).second) swap(*itr++, a); });
  return itr;
}

template<class A>
void let_stable_unique(A& a) {
  a.erase(stable_unique(a.begin(), a.end()), a.end());
}

string name(DCSDictionaryRef dict_ref) {
  return [DCSDictionaryGetName(dict_ref) UTF8String];
}

string short_name(DCSDictionaryRef dict_ref) {
  return [DCSDictionaryGetShortName(dict_ref) UTF8String];
}

map<string, DCSDictionaryRef> const& available_dictionaries() {
  static map<string, DCSDictionaryRef> const s = []() {
    map<string, DCSDictionaryRef> m;
    for (NSObject* dict in DCSCopyAvailableDictionaries()) {
      auto ref = static_cast<DCSDictionaryRef>(dict);
      m.emplace(make_pair(short_name(ref), ref));
    }
    return m;
  }();
  return s;
}

list<string> const& active_dictionaries() {
  static list<string> const s = []() {
    list<string> list;
    for (NSObject* dict in DCSGetActiveDictionaries()) {
      auto ref = static_cast<DCSDictionaryRef>(dict);
      list.emplace_back(short_name(ref));
    }
    list.sort();
    return list;
  }();
  return s;
}

list<string> const& available_dictionary_names() {
  static list<string> const s = []() {
    list<string> list;
    for (auto& i : available_dictionaries()) {
      list.emplace_back(i.first);
    }
    list.sort();
    return list;
  }();
  return s;
}

string lookup(string const& short_name, string const& word) {
  auto& dictionaries = available_dictionaries();
#ifdef _DEBUG
  assert(dictionaries.find(short_name) != dictionaries.end());
#endif
  auto nsword = [NSString stringWithUTF8String:word.c_str()];

  CFRange range;
  range.location = 0;
  range.length = static_cast<CFIndex>([nsword length]);

  auto definition = DCSCopyTextDefinition(
    dictionaries.find(short_name)->second,
    static_cast<CFStringRef>(nsword),
    range);

  if (!definition) return string{};
  return string{ [static_cast<NSString*>(definition) UTF8String] };
}

list<string> dictionaries_from_env() {
  char const* e = getenv(ENV_OSX_DICTIONARY);
  if (!e) {
    return active_dictionaries();
  }
  string s(e);
  if (s.empty()) return list<string>{};
  list<string> dictionaries;
  istringstream iss(s);
  string short_name;
  while (getline(iss, short_name, ':')) {
    if (short_name == "ALL") {
      for (auto& i : available_dictionary_names()) {
        dictionaries.emplace_back(i);
      }
      break;
    }
    if (short_name == "ACTIVE") {
      for (auto& i : active_dictionaries()) {
        dictionaries.emplace_back(i);
      }
    } else {
      dictionaries.emplace_back(move(short_name));
    }
  }
  return move(dictionaries);
}

enum struct output_format {
  plain,
  json,
};

struct arguments {
  arguments(int argc, char* argv[]);

  bool show_help = false;
  bool show_list = false;
  output_format format = output_format::plain;

  list<string> dictionaries;
  list<string> words;
};

void usage(ostream& out, char* pathname) {
  auto name = basename(pathname);
  out << "usage: " << name << " [-a | -A | -d name [-d name]...] [-j] <word> ..." << endl;
  out << "   or: " << name << " -l [-A]" << endl;
  out << endl;
  out << "options:" << endl;
  out << "    -h, --help            print this" << endl;
  out << "    -d, --dictionary <name>" << endl;
  out << "                          look up words in selected dictionaries" << endl;
  out << "    -a, --active          look up words in active dictionaries" << endl;
  out << "    -A, --all             look up words in all dictionaries" << endl;
  out << "    -j, --json            output in json format" << endl;
  out << "    -l, --list            print list of dictionaries" << endl;
  out << "                          with '-A', print list of all available dictionaries" << endl;
  out << endl;
  out << "environment variables:" << endl;
  out << "    OSX_DICTIONARY        A colon-separated list of dictionaries" << endl;
  out << "                          used if there is no dictionary in the command line." << endl;
  out << "                          You can specify ALL or ACTIVE." << endl;
}

arguments::arguments(int argc, char* argv[]) {
  static struct option long_options[] = {
    { "help"      , no_argument      , 0, 'h' },
    { "list"      , no_argument      , 0, 'l' },
    { "json"      , no_argument      , 0, 'j' },
    { "active"    , no_argument      , 0, 'a' },
    { "all"       , no_argument      , 0, 'A' },
    { "dictionary", required_argument, 0, 'd' },
    { 0           , 0                , 0,  0  },
  };
  while (true) {
    int option_index = 0;
    int c = getopt_long(argc, argv, "hljaAd:", long_options, &option_index);
    if (c == -1) break;
    switch (c) {
      case 0:
        cerr << "BUG: option not handled: " << long_options[option_index].name;
        if (optarg) cerr << " with " << optarg;
        cerr << endl;
        exit(1);
      case 'h': case '?':
        show_help = true;
        return;
      case 'l':
        show_list = true;
        break;
      case 'j':
        format = output_format::json;
        break;
      case 'a':
        for (auto& i : active_dictionaries()) {
          dictionaries.emplace_back(i);
        }
        break;
      case 'A':
        for (auto& i : available_dictionary_names()) {
          dictionaries.emplace_back(i);
        }
        break;
      case 'd':
        dictionaries.emplace_back(optarg);
        break;
      default:
        cerr << "BUG: option not handled: " << static_cast<char>(c) << endl;
        exit(1);
    }
  }

  while (optind < argc) {
    words.emplace_back(argv[optind++]);
  }

  if (dictionaries.empty()) {
    dictionaries = dictionaries_from_env();
  }
}

struct printer {
  using String = string const&;
  virtual ~printer() = default;
  virtual void list_item(String short_name, String name) = 0;
  virtual void word(String short_name, String name, String word, String definition) = 0;
  static unique_ptr<printer> get(output_format format);
};

struct plain_printer : printer {
  bool head = true;
  void list_item(String short_name, String name) override {
    cout << short_name << " / " << name << endl;
  }
  void word(String short_name, String name, String word, String definition) override {
    if (head) head = false; else cout << endl;
    cout
      << "word: " << word << endl
      << "from: " << name << " (" << short_name << ')' << endl
      << endl
      << definition << endl;
  }
};

struct json_escape {
  string const& s;
  explicit json_escape(string const& a) : s(a) {}
};

ostream& operator<<(ostream& out, json_escape const& s) {
  out << '"';
  for (auto chr : s.s) {
    switch (chr) {
      case '"' : out << "\\\""; break;
      case '/' : out << "\\/" ; break;
      case '\\': out << "\\\\"; break;
      case '\b': out << "\\b" ; break;
      case '\f': out << "\\f" ; break;
      case '\n': out << "\\n" ; break;
      case '\r': out << "\\r" ; break;
      case '\t': out << "\\t" ; break;
      default:
        if (static_cast<unsigned char>(chr) < 0x20 || chr == 0x7f) {
          out << "\\u" << setw(4) << setfill('0') << hex << (chr & 0xff);
        } else {
          out << chr;
        }
        break;
    }
  }
  return out << '"';
}

struct json_printer : printer {
  bool head = true;
  json_printer() { cout << "["; }
  ~json_printer() { cout << "]"; }
  void list_item(String short_name, String name) override {
    if (head) head = false; else cout << ',';
    cout
      << '{' << json_escape("name"      ) << ':' << json_escape(name)
      << ',' << json_escape("short name") << ':' << json_escape(short_name)
      << '}';
  }
  void word(String short_name, String name, String word, String definition) override {
    if (head) head = false; else cout << ',';
    cout
      << '{' << json_escape("word"      ) << ':' << json_escape(word)
      << ',' << json_escape("name"      ) << ':' << json_escape(name)
      << ',' << json_escape("short name") << ':' << json_escape(short_name)
      << ',' << json_escape("definition") << ':' << json_escape(definition)
      << '}';
  }
};

unique_ptr<printer> printer::get(output_format format) {
  switch (format) {
    case output_format::plain: return unique_ptr<printer>(new plain_printer());
    case output_format::json : return unique_ptr<printer>(new json_printer ());
  }
  assert(false);
}

string name(string const& short_name) {
  return name(available_dictionaries().find(short_name)->second);
}

int osx_dictionary(int argc, char* argv[]) {
  arguments args(argc, argv);

  auto dictionaries = move(args.dictionaries);
  auto words = move(args.words);

  if (args.show_help || dictionaries.empty() || (words.empty() && !args.show_list)) {
    usage(cout, argv[0]);
    return 0;
  }

  let_stable_unique(dictionaries);
  let_stable_unique(words);

  dictionaries.remove_if([](string const& short_name) {
    static auto const& all = available_dictionary_names();
    if (find(all.begin(), all.end(), short_name) != all.end()) return false;
    cerr << "warn: '" << short_name << "' dictionary not found" << endl;
    return true;
  });

  auto prn = printer::get(args.format);

  if (args.show_list) {
    for (auto& short_name : dictionaries) {
      prn->list_item(short_name, name(short_name));
    }
  } else {
    for (auto& word : words) {
      for (auto& short_name : dictionaries) {
        auto const& definition = lookup(short_name, word);
        prn->word(short_name, name(short_name), word, definition);
      }
    }
  }

  return dictionaries.empty() ? 1 : 0;
}

int main(int argc, char* argv[]) {
  @autoreleasepool {
    return osx_dictionary(argc, argv);
  }
}
