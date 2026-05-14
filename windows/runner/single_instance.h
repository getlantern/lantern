#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

class SingleInstanceLock {
 public:
  explicit SingleInstanceLock(const wchar_t* mutex_name);
  ~SingleInstanceLock();

  SingleInstanceLock(const SingleInstanceLock&) = delete;
  SingleInstanceLock& operator=(const SingleInstanceLock&) = delete;

  bool IsPrimaryInstance() const;

 private:
  HANDLE mutex_ = nullptr;
  bool is_primary_instance_ = true;
};

bool ActivateExistingLanternWindow();

#endif  // RUNNER_SINGLE_INSTANCE_H_
