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

class SingleInstanceReadyEvent {
 public:
  explicit SingleInstanceReadyEvent(const wchar_t* event_name);
  ~SingleInstanceReadyEvent();

  SingleInstanceReadyEvent(const SingleInstanceReadyEvent&) = delete;
  SingleInstanceReadyEvent& operator=(const SingleInstanceReadyEvent&) = delete;

  void Signal();
  bool Wait(DWORD timeout_ms) const;

 private:
  HANDLE event_ = nullptr;
};

bool ActivateExistingLanternWindow();
bool ActivateExistingLanternWindowWithRetry(DWORD timeout_ms,
                                            DWORD retry_interval_ms);

#endif  // RUNNER_SINGLE_INSTANCE_H_
