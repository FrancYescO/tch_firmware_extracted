/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
 * Iain Fraser <iainf@netduma.com>
*/

function sampler_circular_array_create(n) {
  return {
    sample_number: 0,
    sample: new Array(n).fill(0)
  };
}

function sampler_circular_array_add(sample_object, value) {
  var position = sampler_get_next_value_position(sample_object);

  sample_object.sample[position] = value;
  sample_object.sample_number += 1;
  return value;
}

function sampler_circular_array_get(sample_object) {
  var output = [];
  var start = Math.max(sample_object.sample_number + 1 - sample_object.sample.length, 1);
  var end = sample_object.sample_number;
  for (var i = start; i <= end; i++) {
    output.push(sample_object.sample[(i - 1) % sample_object.sample.length]);
  }
  return output;
}

function sampler_circular_array_size( sample_object ){
  return Math.min( sample_object.sample.length, sample_object.sample_number );
}

function sampler_circular_array_head(sample_object) {
  return sample_object.sample[sampler_get_last_value_position(sample_object)];
}

function sampler_circular_array_tail(sample_object) {
  if (sample_object.sample_number == 0) {
    throw "Sample contains no values."
  }

  return sample_object.sample[(Math.max(sample_object.sample_number +
          1 - sample_object.sample.length, 1) - 1) % sample_object.sample.length];
}

function sampler_create(n) {
  return sampler_circular_array_create(n);
}

function sampler_get_last_value_position(sample_object) {
  if (sample_object.sample_number == 0) {
    throw "Sample contains no values."
  }

  return (sample_object.sample_number - 1) % sample_object.sample.length;
}

function sampler_get_next_value_position(sample_object) {
  return sample_object.sample_number % sample_object.sample.length;
}

function sampler_add(sample_object, value) {
  if (typeof value != "number") {
    throw "Must be number";
  }

  return sampler_circular_array_add(sample_object, value);
}

function sampler_last(sample_object) {
  return sample_object.sample[sampler_get_last_value_position(sample_object)];
}

function sampler_get(sample_object) {
  return sampler_circular_array_get(sample_object);
}

function sampler_moving_average(sample_object) {
  if (sample_object.sample_number == 0) {
    throw "Sample contains no values.";
  }

  var l = Math.min(sample_object.sample_number, sample_object.sample.length);

  var total = 0;
  for (var i = 0; i < l; i++) {
    total += sample_object.sample[i];
  }

  return total / l;
}

// TODO
function sampler_exponential_average(sample_object) {

}

// TODO
function sampler_cumulative() {

}

function sampler_accumulative_create(n) {
  return {
    sample_object: sampler_create(n)
  };
}

function sampler_accumulative_add(sample_accumulative_object, value, time) {
  var return1;
  var return2;

  if (typeof sample_accumulative_object.last_value != "undefined") {
    var processedValue;
    if (typeof time === "undefined") {
      processedValue = value - sample_accumulative_object.last_value;
      return1 = processedValue
    } else {
      processedValue = (value - sample_accumulative_object.last_value) / time;
      return1 = value - sample_accumulative_object.last_value;
      return2 = processedValue;
    }
    sampler_add(
      sample_accumulative_object.sample_object,
      processedValue
    );
  }
  sample_accumulative_object.last_value = value;

  return [return1, return2];
}

function sampler_accumulative_moving_average(sample_accumulative_object) {
  return sampler_moving_average(sample_accumulative_object.sample_object);
}

function sampler_accumulative_exponential_average(sample_accumulative_object) {
  return sampler_exponential_average(sample_accumulative.sample_object);
}

function sampler_accumulative_get(sample_accumulative_object) {
  return sampler_get(sample_accumulative_object.sample_object);
}

function sampler_accumulative_size( sample_accumulative ){
  return sampler_circular_array_size( sample_accumulative.sample_object ); 
}

