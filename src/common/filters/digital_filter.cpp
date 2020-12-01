#include "digital_filter.h"

#include <cmath>

// #include<ros/console.h>
// #include "cyber/common/log.h"

namespace {
const double kDoubleEpsilon = 1.0e-6;
}  // namespace

namespace fairspace {
namespace common {

DigitalFilter::DigitalFilter(const std::vector<double>& denominators,
                             const std::vector<double>& numerators ) 
{
  set_coefficients(denominators, numerators);
}

void DigitalFilter::set_denominators(const std::vector<double>& denominators) 
{
  denominators_ = denominators;
  y_values_.resize(denominators_.size(), 0.0);
}

void DigitalFilter::set_numerators(const std::vector<double>& numerators) 
{
  numerators_ = numerators;
  x_values_.resize(numerators_.size(), 0.0);
}

void DigitalFilter::set_coefficients(const std::vector<double>& denominators,
                                     const std::vector<double>& numerators ) 
{
  set_denominators(denominators);
  set_numerators(numerators);
}

void DigitalFilter::set_dead_zone(const double deadzone) 
{
  dead_zone_ = std::fabs(deadzone);
  // AINFO << "Setting digital filter dead zone = " << dead_zone_;
}

double DigitalFilter::filter(const double x_insert) 
{
  if (denominators_.empty() || numerators_.empty()) 
  {
    // AERROR << "Empty denominators or numerators";
    return 0.0;
  }

  x_values_.pop_back();
  x_values_.push_front(x_insert);
  const double xside = \
      compute(x_values_, numerators_, 0, numerators_.size() - 1);

  y_values_.pop_back();
  const double yside = \
      compute(y_values_, denominators_, 1, denominators_.size() - 1);

  double y_insert = 0.0;
  if (std::fabs(denominators_.front()) > kDoubleEpsilon) 
  {
    y_insert = (xside - yside) / denominators_.front();
  }
  y_values_.push_front(y_insert);

  return update_last(y_insert);
}

void DigitalFilter::reset_values() 
{
  std::fill(x_values_.begin(), x_values_.end(), 0.0);
  std::fill(y_values_.begin(), y_values_.end(), 0.0);
}

double DigitalFilter::update_last(const double input) 
{
  const double diff = std::fabs(input - last_);
  if (diff < dead_zone_) 
  {
    return last_;
  }
  last_ = input;
  return input;
}

double DigitalFilter::compute(const std::deque<double>& values,
                              const std::vector<double>& coefficients,
                              const std::size_t coeff_start, const std::size_t coeff_end ) 
{
  // ACHECK(coeff_start<=coeff_end && coeff_end<coefficients.size());
  // ACHECK((coeff_end - coeff_start + 1) == values.size());

  double sum = 0.0;
  auto i = coeff_start;
  for (const auto value : values) 
  {
    sum += value * coefficients[i];
    ++i;
  }
  return sum;
}

const std::vector<double>& DigitalFilter::denominators() 
const {
  return denominators_;
}

const std::vector<double>& DigitalFilter::numerators() 
const {
  return numerators_;
}

double DigitalFilter::dead_zone() 
const { 
  return dead_zone_; 
}

const std::deque<double>& DigitalFilter::inputs_queue() 
const {
  return x_values_;
}

const std::deque<double>& DigitalFilter::outputs_queue() 
const {
  return y_values_;
}

}  // namespace common
}  // namespace fairspace