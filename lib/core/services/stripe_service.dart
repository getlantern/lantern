import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService{
  // Add your Stripe service methods here
  // For example, you can create a method to initialize Stripe, handle payments, etc.

  void initialize() {
    // Initialize Stripe with your publishable key
  }

  void handlePayment() {
    // Handle payment logic
  }

  // Add more methods as needed
  void initPaymentSheet(){
    Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(

    ));
  }
}