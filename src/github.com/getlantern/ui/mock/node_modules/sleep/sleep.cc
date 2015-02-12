
#define BUILDING_NODE_EXTENSION

#include <v8.h>
#include <node.h>

#include <unistd.h>


using namespace v8;
using namespace node;


Handle<Value> Sleep(const Arguments& args) {
  HandleScope scope;

  if (args.Length() < 1 || !args[0]->IsUint32()) {
    return ThrowException(Exception::TypeError(String::New("Expected number of seconds")));
  }

  sleep(args[0]->Uint32Value());

  return scope.Close(Undefined());
}

Handle<Value> USleep(const Arguments& args) {
  HandleScope scope;

  if (args.Length() < 1 || !args[0]->IsUint32()) {
    return ThrowException(Exception::TypeError(String::New("Expected number of micro")));
  }

  usleep(args[0]->Uint32Value());

  return scope.Close(Undefined());
}


extern "C" void init(Handle<Object> target) {
  NODE_SET_METHOD(target, "sleep", Sleep);
  NODE_SET_METHOD(target, "usleep", USleep);
}

