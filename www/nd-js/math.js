/*
* (C) Iain Fraser - NetDuma
* Generic math code
*/

function vec2( x, y ){
	return { x : x, y : y };
}

function vec2_add( U, V ) {
  return { x : U.x + V.x, y : U.y + V.y };
}

function vec2_sub( U, V ){
  return { x : U.x - V.x, y : U.y - V.y };
}

function vec2_mag( U ){
  return Math.sqrt( U.x*U.x + U.y*U.y );
}

function vec2_mul( U, a ){
  return { x : U.x * a, y : U.y * a };
}

function vec2_cross( U ){
  return { x : -U.y, y : U.x }
}

function horizontal_line( y ){
  return { a : 0, b : 1, c : -y };
}

function vertical_line( x ){
  return { a : 1, b : 0, c : -x };
}

function points_to_line( U, V ){
  var m,k;

  if( V.x == U.x  ) 
          return { a : 1, b : 0, c : -V.x };
  else
          m = ( V.y - U.y ) / ( V.x - U.x );

  k = V.y - m * V.x;
  return { a : -m, b : 1, c : -k };
}

function polygon_to_lines( polygon ){
  var n = polygon.length;
  var lines = [];

  for( i = 0; i < n; i++ ){
      var dst = i == n - 1 ? 0 : (i+1);
      lines.push( points_to_line( polygon[i], polygon[dst] ) );
  }

  return lines
}

function degree_to_rad( degree ){
  return degree * ( Math.PI / 180 );
}

