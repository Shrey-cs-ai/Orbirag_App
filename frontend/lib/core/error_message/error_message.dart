class ErrorMessages {
  static String fromStatusCode(int code) {
    switch (code) {
      case 400:
        return "Bad request. Please check your input.";
      case 401:
        return "Unauthorized. Please log in again.";
      case 403:
        return "You don't have permission to do this.";
      case 404:
        return "Requested data not found.";
      case 408:
        return "Request timed out. Try again.";
      case 429:
        return "Too many requests. Please wait a moment.";
      case 500:
        return "Server error. Please try again later.";
      case 503:
        return "Service unavailable. Try again later.";
      default:
        return "Something went wrong ($code).";
    }
  }
}