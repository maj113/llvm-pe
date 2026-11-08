// LLVM's CMake check HAVE_BUILTIN_THREAD_POINTER: a fatal backend error on Windows.
void *thread_pointer(void) { return __builtin_thread_pointer(); }
